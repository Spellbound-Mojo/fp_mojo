"""Runtime-built and recursive IO programs a million steps deep, run without native recursion."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, OnceThunk
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from state_machine import IO, Machine, Step, Wait, Task, run
from foundation import check, Failure

comptime DEPTH = 1_000_000


@fieldwise_init
struct AddOne(OnceUnary):
    """A continuation counting its unopened drops."""
    var dropped: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def __deinit__(deinit self):
        self.dropped[][0] += 1

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value + 1)


@fieldwise_init
struct Increment(OnceUnary):
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value + 1


def counted(n: Int) -> IO[Int, Failure]:
    """Right-nested recursion: each level maps over the next, so frames grow to n."""
    if n == 0:
        return IO[Int, Failure].pure(0)
    return IO[Int, Failure].defer(Counted(n)).map(Increment())


@fieldwise_init
struct Counted(OnceThunk):
    var n: Int
    comptime Out = IO[Int, Failure]
    comptime Error = Never

    def call_once(deinit self) -> IO[Int, Failure]:
        return counted(self.n - 1)


@fieldwise_init
struct Loop(OnceUnary):
    """Tail recursion through a continuation: frames stay bounded."""
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        if value == self.limit:
            return IO[Int, Failure].pure(value)
        return IO[Int, Failure].pure(value + 1).flat_map(Loop(self.limit))


@fieldwise_init
struct Recover(OnceUnary):
    comptime Arg = EffectFailure[Failure]
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var failure: EffectFailure[Failure]) -> IO[Int, Failure]:
        var errors = failure^.into_errors().into_list()
        return IO[Int, Failure].pure(-errors[0].code)


@fieldwise_init
struct Forever(Machine):
    comptime Value = Int
    comptime Error = Failure

    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        if context.canceled():
            return .ready(None)
        return .pending(Wait.never())


def left_chain(var source: IO[Int, Failure], dropped: ArcPointer[List[Int]]) -> IO[Int, Failure]:
    # One stable type at every depth: the loop instantiates no new type.
    var io = source^
    for _ in range(DEPTH):
        io = io^.flat_map(AddOne(dropped.copy()))
    return io^


def new_counter() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]([0]))


def runtime_left_chain():
    var dropped = new_counter()
    var outcome = run(left_chain(IO[Int, Failure].pure(0), dropped))
    check(outcome.take()._take_ok() == DEPTH, "a million runtime-built binds")
    check(dropped[][0] == 0, "every continuation invoked")


def recursive_frames():
    var outcome = run(counted(DEPTH))
    check(outcome.take()._take_ok() == DEPTH, "a million nested deferred levels")


def tail_recursion():
    var outcome = run(IO[Int, Failure].pure(0).flat_map(Loop(DEPTH)))
    check(outcome.take()._take_ok() == DEPTH, "a million tail-recursive steps")


def unopened_disposal():
    var dropped = new_counter()
    var io = left_chain(IO[Int, Failure].pure(0), dropped)
    _ = io^
    check(dropped[][0] == DEPTH, "an unopened million-step chain destroyed iteratively")


def deep_failure_and_recovery():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0]))
    var dropped = new_counter()
    var failing = left_chain(IO[Int, Failure].raise_error(Failure(9, stats.copy())), dropped)
    var outcome = run(failing^.handle_error_with(Recover()))
    check(outcome.take()._take_ok() == -9, "failure crosses a million frames to recovery")
    check(dropped[][0] == DEPTH and stats[][4] == 1, "skipped continuations and the failure destroyed once")


def deep_cancellation():
    var dropped = new_counter()
    var task = Task(left_chain(IO[Int, Failure].lift(Forever()), dropped), CancellationToken())
    while task.tick():
        pass
    check(not task.done(), "parked under a million pending frames")
    task.cancel()
    while not task.done():
        _ = task.tick()
    var outcome = task^.finish()
    check(not outcome and dropped[][0] == DEPTH, "cancellation unwinds every frame once")


def main():
    runtime_left_chain()
    recursive_frames()
    tail_recursion()
    unopened_disposal()
    deep_failure_and_recovery()
    deep_cancellation()
    print("io depth: runtime-built, recursive and tail-recursive programs, disposal, failure and cancellation a million steps deep")
