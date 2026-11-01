"""GenSpawn laws that hold on Async, and the recorded owner-draining difference."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk, OnceUnary
from fp.effects import Outcome, Spawn, delay, raise_error, start, join, cancel, never, cede, uncancelable
from fp.effects.async_runtime import IO, Async, Fiber, Poll, run

comptime I = Async[Int]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def summary(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Count(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.calls[] += 1
        return 7


@fieldwise_init
struct Join(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return join[I, Int](fiber^).map(Summary())


@fieldwise_init
struct Summary(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return summary(outcome^)


@fieldwise_init
struct CancelJoin(OnceUnary):
    """Let the child enter, cancel it and wait, then join it."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return cede[I]().flat_map(CancelThen(fiber^))


@fieldwise_init
struct CancelThen(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var stopping = cancel[I, Int](self.fiber)
        return stopping^.flat_map(JoinAfter(self.fiber^))


@fieldwise_init
struct JoinAfter(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return join[I, Int](self.fiber^).map(Summary())


@fieldwise_init
struct Masked(OnceUnary):
    """A region that ignores its poll."""
    var calls: ArcPointer[Int]
    comptime Arg = Poll[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var poll: Poll[Int]) -> IO[Int, Int]:
        return cede[I]().flat_map(Then(self.calls^))


@fieldwise_init
struct Then(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        # The whole of fa runs masked; a bind after the region would observe
        # the cancellation, depending on when the canceler runs.
        return IO[NoneType, Int].delay(Bump(self.calls^)).map(Seven())


@fieldwise_init
struct Bump(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        self.calls[] += 1
        return None


@fieldwise_init
struct Seven(OnceUnary):
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return 7


@fieldwise_init
struct Drop(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> Int:
        return 1


def main():
    var calls = ArcPointer(0)
    # start(fa).flatMap(join) == fa.map(Succeeded)
    check(summary(run(start[I](delay[I](Count(calls.copy()))).flat_map(Join()))) == 7 and calls[] == 1, "a joined success")
    # start(raise(e)).flatMap(join) == pure(Errored(e))
    check(summary(run(start[I](raise_error[I, Int](Int(4))).flat_map(Join()))) == -1004, "a joined failure")
    # start(never).flatMap(f => f.cancel >> f.join) == pure(Canceled)
    check(summary(run(start[I](never[I, Int]()).flat_map(CancelJoin()))) == -2, "a canceled waiting fiber joins as canceled")
    # start(uncancelable(_ => fa)) canceled then joined completes fa.
    calls[] = 0
    var masked = uncancelable[I](Masked(calls.copy()))
    check(summary(run(start[I](masked^).flat_map(CancelJoin()))) == 7 and calls[] == 1, "a fully masked fiber completes despite cancellation")
    # Recorded difference: a fiber never outlives its owner. Cats Effect leaves it running.
    calls[] = 0
    var dropped = start[I](cede[I]().flat_map(Then(calls.copy()))).map(Drop())
    check(summary(run(dropped^)) == 1, "the owner's outcome ignores an unjoined child")
    check(calls[] <= 1, "the owner drained its child before completing")
    print("spawn laws: joined success, failure and cancellation, masked fibers, owner draining")
