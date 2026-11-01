"""Execution contexts: `eval_on`, `start_on` and `execution_context` on every target.

Each part runs on three targets: a two-worker work-stealing `Runtime`, a
current-thread `Runtime`, and a two-thread `BlockingPool`. The caller is the
free `run`, on whichever profile the build selects.

- **Outcomes.** A success, an error and a self-cancellation pass through a
  region unchanged.
- **Where code runs.** The region runs on a thread other than the caller's;
  under a current-thread caller, the caller resumes on its own thread.
- **`execution_context`.** None under the free `run`; the target inside a
  region; the runtime inside `runtime.run`; and nested regions return to each
  caller's context.
- **Ownership.** A child the region starts and never joins is canceled and
  drained when the region ends: its finalizer has run when the caller resumes.
- **`start_on`.** A child whose work runs on the target, joined by its owner.
- **Many regions.** 200 regions in sequence and 50 started at once, so the
  runtimes' registries return to empty.
"""
from std.ffi import external_call
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Deferred, BlockingPool, ExecutionContext, IORuntimeConfig, Profile, Runtime, run
from fp.effects._async.profile import _PROFILE


def check(condition: Bool, message: String):
    if not condition:
        abort(String("eval_on_basics: ", message))


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def stealing(workers: Int) -> IORuntimeConfig:
    var config = IORuntimeConfig()
    try:
        config.profile = Profile.work_stealing(workers)
    except:
        abort("a valid worker count")
    return config^


def current() -> IORuntimeConfig:
    var config = IORuntimeConfig()
    config.profile = Profile.current_thread()
    return config^


# ===--- Programs ---=== #


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


struct Pair[A: Copyable & Deinitable](OnceUnary):
    """Pair a first value with the second one's."""
    var first: Self.A
    comptime Arg = Self.A
    comptime Out = Tuple[Self.A, Self.A]

    def __init__(out self, var first: Self.A):
        self.first = first^

    def call_once(deinit self, var second: Self.A) -> Tuple[Self.A, Self.A]:
        return (self.first^, second^)


struct ThenThread(OnceUnary, Defaultable):
    """After a region's thread, read the caller's thread: (region, caller)."""
    comptime Arg = UInt64
    comptime Out = IO[Tuple[UInt64, UInt64], Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var region: UInt64) -> IO[Tuple[UInt64, UInt64], Int]:
        return IO[UInt64, Int].delay(thread_id).map(Pair[UInt64](region))


comptime Context = Optional[ExecutionContext]


struct ThenContext(OnceUnary, Defaultable):
    """After an inner region's context, read the caller's own: (inner, outer)."""
    comptime Arg = Context
    comptime Out = IO[Tuple[Context, Context], Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var inner: Context) -> IO[Tuple[Context, Context], Int]:
        return IO[Context, Int].execution_context().map(Pair[Context](inner^))


@fieldwise_init
struct Mark(OnceUnary):
    """A finalizer: complete the cell with 1."""
    var cell: Deferred[Int]
    comptime Arg = Bool
    comptime Out = NoneType

    def call_once(deinit self, var completed: Bool) -> NoneType:
        return None


def mark(cell: Deferred[Int]) -> IO[NoneType, Int]:
    return cell.complete[Int](1).map(Mark(cell.copy()))


@fieldwise_init
struct Abandon(OnceUnary):
    """Drop the started child's handle once it runs, so the region's end must drain it."""
    var running: Deferred[Int]
    var value: Int
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Int, Int]:
        return self.running.get[Int]().map(Add(self.value - 1))


@fieldwise_init
struct WaitForever(OnceUnary):
    """After reporting that it runs, wait until canceled, marking the cell then."""
    var cell: Deferred[Int]
    comptime Arg = Bool
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var completed: Bool) -> IO[NoneType, Int]:
        return IO[NoneType, Int].never().on_cancel(mark(self.cell))


@fieldwise_init
struct ReadCell(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = Int
    comptime Out = IO[Optional[Int], Int]

    def call_once(deinit self, var value: Int) -> IO[Optional[Int], Int]:
        check(value == 5, "the region's value")
        return self.cell.try_get[Int]()


struct JoinValue(OnceUnary, Defaultable):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join_with(IO[Int, Int].pure(-1))


@fieldwise_init
struct Add(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


@fieldwise_init
struct SumNext(OnceUnary):
    """Run the next region and add its value."""
    var target: ExecutionContext
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        return sequence(self.target, self.left, total)


def sequence(target: ExecutionContext, left: Int, total: Int) -> IO[Int, Int]:
    if left == 0:
        return IO[Int, Int].pure(total)
    return IO[Int, Int].pure(left).eval_on(target).map(Add(total)).flat_map(SumNext(target.copy(), left - 1))


@fieldwise_init
struct JoinAll(OnceUnary):
    """Join started fibers one by one, adding their values."""
    var target: ExecutionContext
    var left: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var rest = fan(self.target, self.left - 1)
        return rest^.flat_map(JoinAdd(fiber^))


struct JoinAdd(OnceUnary):
    var fiber: Optional[Fiber[Int, Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def __init__(out self, var fiber: Fiber[Int, Int]):
        self.fiber = Optional(fiber^)

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        return self.fiber.take().join_with(IO[Int, Int].pure(-1000)).map(Add(total))


def fan(target: ExecutionContext, left: Int) -> IO[Int, Int]:
    """Start `left` regions at once with `start_on`, then join them all."""
    if left == 0:
        return IO[Int, Int].pure(0)
    return IO[Int, Int].pure(left).start_on(target).flat_map(JoinAll(target.copy(), left))


# ===--- Parts ---=== #


def outcomes(target: ExecutionContext, name: String):
    check(value_of(run(IO[Int, Int].pure(42).eval_on(target))) == 42, name + ": a success passes through")
    var failed = run(IO[Int, Int].raise_error(7).eval_on(target))
    check(Bool(failed) and failed.value().is_err(), name + ": an error passes through")
    var failure = failed.take()._take_err()
    check(len(failure.errors) == 1 and failure.errors.first() == 7 and not failure.canceled, name + ": the exact error")
    var canceled = run(IO[NoneType, Int].canceled().map(Const(1)).eval_on(target))
    check(not canceled, name + ": a region that cancels itself cancels its caller")


def threads(target: ExecutionContext, name: String):
    var main = thread_id()
    var pair = value_of(run(IO[UInt64, Int].delay(thread_id).eval_on(target).flat_map(ThenThread())))
    check(pair[0] != main, name + ": the region runs on the target's thread")
    if _PROFILE == "current_thread":
        check(pair[1] == main, name + ": the caller resumes on its own thread")


def contexts(target: ExecutionContext, name: String):
    var outside = value_of(run(IO[Context, Int].execution_context()))
    check(not outside, name + ": no context under the free run")
    var inside = value_of(run(IO[Context, Int].execution_context().eval_on(target)))
    check(Bool(inside) and inside.value() == target, name + ": the target inside its region")


def nested(outer: ExecutionContext, inner: ExecutionContext, name: String):
    var both = value_of(run(IO[Context, Int].execution_context().eval_on(inner).flat_map(ThenContext()).eval_on(outer)))
    check(Bool(both[0]) and both[0].value() == inner, name + ": the inner region's context")
    check(Bool(both[1]) and both[1].value() == outer, name + ": back in the outer region's context")


def drained(target: ExecutionContext, name: String):
    var cell = Deferred[Int]()
    var running = Deferred[Int]()
    var child = running.complete[Int](1).flat_map(WaitForever(cell.copy()))
    var region = child^.start().flat_map(Abandon(running.copy(), 5)).eval_on(target)
    var seen = value_of(run(region^.flat_map(ReadCell(cell.copy()))))
    check(Bool(seen) and seen.value() == 1, name + ": the region's child was canceled and drained at its end")


def started(target: ExecutionContext, name: String):
    check(value_of(run(IO[Int, Int].pure(9).start_on(target).flat_map(JoinValue()))) == 9, name + ": start_on's child joins")
    check(value_of(run(sequence(target, 200, 0))) == 200 * 201 // 2, name + ": 200 regions in sequence")
    check(value_of(run(fan(target, 50))) == 50 * 51 // 2, name + ": 50 regions at once")


def every_part(target: ExecutionContext, name: String):
    outcomes(target, name)
    threads(target, name)
    contexts(target, name)
    drained(target, name)
    started(target, name)


def main():
    var pooled: Runtime
    var single: Runtime
    var blocking: BlockingPool
    try:
        pooled = Runtime(stealing(2))
        single = Runtime(current())
    except:
        abort("eval_on_basics: the runtimes start")
    try:
        blocking = BlockingPool(max_workers=2)
    except:
        abort("eval_on_basics: the blocking pool's configuration")
    every_part(pooled, "work-stealing runtime")
    every_part(single, "current-thread runtime")
    every_part(blocking, "blocking pool")
    nested(pooled, single, "pool then current thread")
    nested(single, blocking, "current thread then blocking pool")
    nested(blocking, pooled, "blocking pool then pool")
    nested(pooled, pooled, "the same runtime twice")
    # `runtime.run` gives its program that runtime as its context.
    var inside = value_of(pooled.run(IO[Context, Int].execution_context()))
    check(Bool(inside) and inside.value() == ExecutionContext(pooled), "runtime.run's context on the pool")
    inside = value_of(single.run(IO[Context, Int].execution_context()))
    check(Bool(inside) and inside.value() == ExecutionContext(single), "runtime.run's context on the current thread")
    check(len(pooled.fibers()) == 0 and len(single.fibers()) == 0, "no root is left registered")
    check(ExecutionContext(pooled) != ExecutionContext(single) and ExecutionContext(pooled) == ExecutionContext(pooled.copy()), "contexts compare by identity")
    print("eval_on basics: outcomes, threads, contexts, nesting, drained children and start_on on every target")
    print(String(ExecutionContext(single)), String(ExecutionContext(blocking)))
