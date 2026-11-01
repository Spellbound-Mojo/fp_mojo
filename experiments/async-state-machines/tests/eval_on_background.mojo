"""`background` and `background_on`: fibers for a resource's use.

- **Joined in use.** `io.background().use(join)` produces the fiber's
  outcome: a success, an error, a cancellation.
- **Not joined.** A fiber still running when the use ends is canceled and
  waited for: its finalizer has run once when the resource's `use` returns.
- **Canceled through the handle.** `Background.cancel` in the body.
- **On every target.** `background_on(target)` runs the fiber's work on a
  work-stealing runtime, a current-thread runtime and a blocking pool, where
  `execution_context` is the target.
- **Generic and through layers.** `background[Async[Int]]`,
  `background[LiftSpawn[OptionalT[...], ...]]`, `background_on[Async[Int]]`
  and `background_on[LiftEvalOn[OptionalT[...], ...]]`.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from fp.callables import BorrowCallable, OnceThunk, OnceUnary
from fp.effects import Outcome, OptionalT, LiftSpawn, LiftEvalOn, background, background_on
from fp.effects.async_runtime import IO, Async, Background, Deferred, BlockingPool, ExecutionContext, IORuntimeConfig, Profile, Runtime, run

comptime A = Async[Int]
comptime O = OptionalT[A]
comptime Context = Optional[ExecutionContext]
comptime Counter = ArcPointer[Atomic[Int]]


def check(condition: Bool, message: String):
    if not condition:
        abort(String("eval_on_background: ", message))


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


@fieldwise_init
struct Bump(OnceThunk):
    var counter: Counter
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        _ = self.counter[].fetch_add(1)
        return None


def join_int(handle: Background[Int, Int]) -> IO[Outcome[Int, Int], Int]:
    return handle.join()


def join_context(handle: Background[Context, Int]) -> IO[Outcome[Context, Int], Int]:
    return handle.join()


def join_layer(handle: Background[Optional[Int], Int]) -> IO[Outcome[Optional[Int], Int], Int]:
    return handle.join()


def cancel_then_join(handle: Background[Int, Int]) -> IO[Outcome[Int, Int], Int]:
    return handle.cancel().flat_map(JoinAfter(handle.join()))


struct JoinAfter(OnceUnary):
    var join: Optional[IO[Outcome[Int, Int], Int]]
    comptime Arg = NoneType
    comptime Out = IO[Outcome[Int, Int], Int]

    def __init__(out self, var join: IO[Outcome[Int, Int], Int]):
        self.join = Optional(join^)

    def call_once(deinit self, var unit: NoneType) -> IO[Outcome[Int, Int], Int]:
        return self.join.take()


struct Forever(OnceUnary, Defaultable):
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var completed: Bool) -> IO[Int, Int]:
        return IO[Int, Int].never()


@fieldwise_init
struct WaitRunning(BorrowCallable):
    """Once the fiber runs, leave the use without joining it."""
    var running: Deferred[Int]
    comptime Payload = Background[Int, Int]
    comptime Result = IO[Int, Int]
    comptime Failure = Never

    def invoke(self, ref handle: Background[Int, Int]) -> IO[Int, Int]:
        return self.running.get[Int]()


def outcomes():
    var joined = value_of(run(IO[Int, Int].pure(5).background().use(join_int)))
    check(Bool(joined) and joined.value().is_ok() and joined.take()._take_ok() == 5, "a joined success")
    var failed = value_of(run(IO[Int, Int].raise_error(6).background().use(join_int)))
    check(Bool(failed) and failed.value().is_err(), "a joined failure")
    var canceled = value_of(run(IO[Int, Int].never().background().use(cancel_then_join)))
    check(not canceled, "a fiber canceled through its handle joins canceled")


def released():
    var finalized = Counter(Atomic[Int](0))
    for _ in range(50):
        var running = Deferred[Int]()
        var fiber = running.complete[Int](1).flat_map(Forever()).on_cancel(IO[NoneType, Int].delay(Bump(finalized.copy())))
        var before = finalized[].load()
        var used = run(fiber^.background().use(WaitRunning(running.copy())))
        check(Bool(used) and used.value().is_ok(), "the use ends without joining")
        check(finalized[].load() == before + 1, "release canceled the fiber and waited for its finalizer")


def targets(target: ExecutionContext, name: String):
    var joined = value_of(run(IO[Int, Int].pure(7).background_on(target).use(join_int)))
    check(Bool(joined) and joined.take()._take_ok() == 7, name + ": background_on joins")
    var seen = value_of(run(IO[Context, Int].execution_context().background_on(target).use(join_context)))
    check(Bool(seen) and seen.value().is_ok(), name + ": the context read in the background succeeds")
    var context = seen.take()._take_ok()
    check(Bool(context) and context.value() == target, name + ": the background fiber runs on the target")
    var generic = value_of(run(background_on[A](IO[Int, Int].pure(8), target).use(join_int)))
    check(Bool(generic) and generic.take()._take_ok() == 8, name + ": background_on[Async]")
    var layered = value_of(run(background_on[LiftEvalOn[O, A]](IO[Optional[Int], Int].pure(Optional(9)), target).use(join_layer)))
    check(Bool(layered) and layered.take()._take_ok() == Optional(9), name + ": background_on through OptionalT")


def generic():
    var joined = value_of(run(background[A](IO[Int, Int].pure(4)).use(join_int)))
    check(Bool(joined) and joined.take()._take_ok() == 4, "background[Async]")
    var layered = value_of(run(background[LiftSpawn[O, A]](IO[Optional[Int], Int].pure(Optional[Int]())).use(join_layer)))
    check(Bool(layered) and layered.value().is_ok() and not layered.take()._take_ok(), "background through OptionalT joins the layer's absence")


def main():
    var pooled: Runtime
    var single: Runtime
    var blocking: BlockingPool
    try:
        var config = IORuntimeConfig()
        config.profile = Profile.work_stealing(2)
        pooled = Runtime(config)
        var current = IORuntimeConfig()
        current.profile = Profile.current_thread()
        single = Runtime(current)
    except:
        abort("eval_on_background: the runtimes start")
    try:
        blocking = BlockingPool(max_workers=2)
    except:
        abort("eval_on_background: the blocking pool's configuration")
    outcomes()
    released()
    targets(pooled, "work-stealing runtime")
    targets(single, "current-thread runtime")
    targets(blocking, "blocking pool")
    generic()
    print("eval_on background: joins, release cancels, background_on on every target, generic and through layers")
