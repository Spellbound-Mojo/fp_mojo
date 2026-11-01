"""One generic program over Defer, Raise and Cancel, run on SyncIO and Async with identical results."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk, OnceUnary
from fp.effects import Outcome, EffectFailure, Defer, Raise, Cancel, SyncIO, run_io, delay, defer, raise_error, canceled, guarantee, on_cancel, uncancelable
from fp.effects.async_runtime import Async, run


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
struct Mark(OnceThunk):
    var marks: ArcPointer[Int]
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        self.marks[] += 1
        return None


@fieldwise_init
struct Fail(OnceThunk):
    comptime Out = Int
    comptime Error = Int

    def call_once(deinit self) raises Int -> Int:
        raise 4


@fieldwise_init
struct Region[I: Defer & Cancel](OnceUnary):
    """A masked region that ignores its poll and counts once."""
    var calls: ArcPointer[Int]
    comptime Arg = Self.I.RegionPoll
    comptime Out = Self.I.Delayed[Count]

    def call_once(deinit self, var poll: Self.I.RegionPoll) -> Self.I.Delayed[Count]:
        comptime assert Self.I.DelayCompatible[Count]
        return delay[Self.I](Count(self.calls^))


def guarded[I: Defer & Cancel](calls: ArcPointer[Int], marks: ArcPointer[Int]) -> I.Guaranteed[I.Delayed[Count], I.Delayed[Mark]] where I.DelayCompatible[Count] and I.DelayCompatible[Mark] and I.GuaranteeCompatible[I.Delayed[Count], I.Delayed[Mark]]:
    return guarantee[I](delay[I](Count(calls.copy())), delay[I](Mark(marks.copy())))


def failing[I: Defer & Cancel](marks: ArcPointer[Int]) -> I.Guaranteed[I.Delayed[Fail], I.Delayed[Mark]] where I.DelayCompatible[Fail] and I.DelayCompatible[Mark] and I.GuaranteeCompatible[I.Delayed[Fail], I.Delayed[Mark]]:
    return guarantee[I](delay[I](Fail()), delay[I](Mark(marks.copy())))


def only_on_cancel[I: Defer & Cancel](calls: ArcPointer[Int], marks: ArcPointer[Int]) -> I.OnCanceled[I.Delayed[Count], I.Delayed[Mark]] where I.DelayCompatible[Count] and I.DelayCompatible[Mark] and I.GuaranteeCompatible[I.Delayed[Count], I.Delayed[Mark]]:
    return on_cancel[I](delay[I](Count(calls.copy())), delay[I](Mark(marks.copy())))


def masked[I: Defer & Cancel](calls: ArcPointer[Int]) -> I.Uncanceled[Region[I]] where I.UncancelableCompatible[Region[I]]:
    return uncancelable[I](Region[I](calls.copy()))


def summary(var outcome: Outcome[Int, Int]) -> Int:
    """A success's value, -1000 - error for a failure, -2 for cancellation."""
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    var failure = result^._take_err()
    check(not failure.canceled, "ordinary failures are not marked canceled")
    return -1000 - failure.errors.first()


def main() raises:
    var calls = ArcPointer(0)
    var marks = ArcPointer(0)
    var sync = summary(run_io(guarded[SyncIO[Int]](calls, marks)))
    var sync_marks = marks[]
    calls[] = 0
    marks[] = 0
    var asynchronous = summary(run(guarded[Async[Int]](calls, marks)))
    check(sync == 10 and asynchronous == 10 and sync_marks == 1 and marks[] == 1, "guarantee runs the body, then the finalizer, on both providers")

    marks[] = 0
    var sync_failed = summary(run_io(failing[SyncIO[Int]](marks)))
    var async_failed = summary(run(failing[Async[Int]](marks)))
    check(sync_failed == -1004 and async_failed == -1004 and marks[] == 2, "a failing body still runs the finalizer on both providers")

    calls[] = 0
    marks[] = 0
    _ = run_io(only_on_cancel[SyncIO[Int]](calls, marks))
    _ = run(only_on_cancel[Async[Int]](calls, marks))
    check(calls[] == 2 and marks[] == 0, "on_cancel skips its finalizer when nothing is canceled")

    calls[] = 0
    check(summary(run_io(masked[SyncIO[Int]](calls))) == 10, "a masked region runs on SyncIO")
    check(summary(run(masked[Async[Int]](calls))) == 20, "a masked region runs on Async")

    check(summary(run_io(raise_error[SyncIO[Int], Int](Int(6)))) == -1006, "raise_error on SyncIO")
    check(summary(run(raise_error[Async[Int], Int](Int(6)))) == -1006, "raise_error on Async")

    var sync_canceled = run_io(canceled[SyncIO[Int]]())
    var async_canceled = run(canceled[Async[Int]]())
    check(not sync_canceled and not async_canceled, "canceled ends the program as canceled on both providers")
    print("capability cancel: one generic program over SyncIO and Async")
