"""Generic programs over Spawn and Defer: start, join, cancel, cede, never and defer."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk, OnceUnary
from fp.effects import Outcome, Defer, Raise, Cancel, Spawn, SyncIO, run_io, delay, defer, raise_error, start, join, cancel, cede, never
from fp.effects.async_runtime import IO, Async, Fiber, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct Count(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.calls[] += 1
        return self.calls[] * 10


@fieldwise_init
struct Build[I: Defer](OnceThunk):
    """Build the counting program only when reached."""
    var calls: ArcPointer[Int]
    var built: ArcPointer[Int]
    comptime Out = Self.I.Delayed[Count]
    comptime Error = Never

    def call_once(deinit self) -> Self.I.Delayed[Count]:
        comptime assert Self.I.DelayCompatible[Count]
        self.built[] += 1
        return delay[Self.I](Count(self.calls^))


def deferred[I: Defer](calls: ArcPointer[Int], built: ArcPointer[Int]) -> I.Deferred[Build[I]] where I.DeferCompatible[Build[I]]:
    return defer[I](Build[I](calls.copy(), built.copy()))


@fieldwise_init
struct JoinValue[I: Spawn](OnceUnary):
    """Join a started fiber and keep its outcome."""
    comptime Arg = Self.I.Handle[Int]
    comptime Out = Self.I.Joined[Int]

    def call_once(deinit self, var fiber: Self.I.Handle[Int]) -> Self.I.Joined[Int]:
        return join[Self.I, Int](fiber^)


def summary(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Joined(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return summary(outcome^)


@fieldwise_init
struct CancelThenJoin(OnceUnary):
    """Cancel a waiting fiber, then join it."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Outcome[Int, Int], Int]:
        var stopping = cancel[Async[Int], Int](fiber)
        return stopping^.flat_map(JoinAfter(fiber^))


@fieldwise_init
struct JoinAfter(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Outcome[Int, Int], Int]:
        return join[Async[Int], Int](self.fiber^)


@fieldwise_init
struct Then5(OnceUnary):
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].pure(5)


def main() raises:
    var calls = ArcPointer(0)
    var built = ArcPointer(0)
    var sync = deferred[SyncIO[Int]](calls, built)
    check(built[] == 0, "defer builds nothing at construction")
    check(summary(run_io(sync^)) == 10 and built[] == 1, "defer builds and runs when reached on SyncIO")
    check(summary(run(deferred[Async[Int]](calls, built))) == 20 and built[] == 2, "defer builds and runs when reached on Async")

    var started = start[Async[Int]](IO[Int, Int].pure(5)).flat_map(JoinValue[Async[Int]]()).map(Joined())
    check(summary(run(started^)) == 5, "start then join produces the child's success")
    var failing = start[Async[Int]](raise_error[Async[Int], Int](Int(3))).flat_map(JoinValue[Async[Int]]()).map(Joined())
    check(summary(run(failing^)) == -1003, "start then join produces the child's failure")
    var stopped = start[Async[Int]](never[Async[Int], Int]()).flat_map(CancelThenJoin()).map(Joined())
    check(summary(run(stopped^)) == -2, "cancel then join produces cancellation")
    var ceded = cede[Async[Int]]().flat_map(Then5())
    check(summary(run(ceded^)) == 5, "cede yields once and continues")
    print("capability spawn: generic defer on SyncIO and Async; start, join, cancel, cede and never on Async")
