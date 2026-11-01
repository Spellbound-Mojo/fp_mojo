"""MonadCancel laws that hold, checked by one generic program on SyncIO and Async."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk, OnceUnary
from fp.effects import Outcome, EffectFailure, Defer, Cancel, SyncIO, run_io, delay, canceled, guarantee, on_cancel, uncancelable, restore, raise_error
from fp.effects.async_runtime import IO, Async, run


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
struct Log(OnceThunk):
    """Append a code to the shared order log."""
    var log: ArcPointer[List[Int]]
    var code: Int
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        self.log[].append(self.code)
        return None


@fieldwise_init
struct PollIdentity[I: Defer & Cancel](OnceUnary):
    """The region uncancelable(poll => poll(fa)), restoring its whole body."""
    var calls: ArcPointer[Int]
    comptime Arg = Self.I.RegionPoll
    comptime Out = Self.I.Restored[Self.I.Delayed[Count]]

    def call_once(deinit self, var poll: Self.I.RegionPoll) -> Self.Out:
        comptime assert Self.I.DelayCompatible[Count] and Self.I.RestoreCompatible[Self.I.Delayed[Count]]
        return restore[Self.I](poll, delay[Self.I](Count(self.calls^)))


def summary(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


def poll_identity[I: Defer & Cancel](calls: ArcPointer[Int]) -> I.Uncanceled[PollIdentity[I]] where I.UncancelableCompatible[PollIdentity[I]]:
    return uncancelable[I](PollIdentity[I](calls.copy()))


def plain[I: Defer & Cancel](calls: ArcPointer[Int]) -> I.Delayed[Count] where I.DelayCompatible[Count]:
    return delay[I](Count(calls.copy()))


def guarded[I: Defer & Cancel](calls: ArcPointer[Int], log: ArcPointer[List[Int]]) -> I.Guaranteed[I.Delayed[Count], I.Delayed[Log]] where I.DelayCompatible[Count] and I.DelayCompatible[Log] and I.GuaranteeCompatible[I.Delayed[Count], I.Delayed[Log]]:
    return guarantee[I](delay[I](Count(calls.copy())), delay[I](Log(log.copy(), 1)))


def nested[I: Defer & Cancel](calls: ArcPointer[Int], log: ArcPointer[List[Int]]) -> I.Guaranteed[I.Guaranteed[I.Delayed[Count], I.Delayed[Log]], I.Delayed[Log]] where I.DelayCompatible[Count] and I.DelayCompatible[Log] and I.GuaranteeCompatible[I.Delayed[Count], I.Delayed[Log]] and I.GuaranteeCompatible[I.Guaranteed[I.Delayed[Count], I.Delayed[Log]], I.Delayed[Log]]:
    var inner = guarantee[I](delay[I](Count(calls.copy())), delay[I](Log(log.copy(), 1)))
    return guarantee[I](inner^, delay[I](Log(log.copy(), 2)))


def unobserved[I: Defer & Cancel](calls: ArcPointer[Int], log: ArcPointer[List[Int]]) -> I.OnCanceled[I.Delayed[Count], I.Delayed[Log]] where I.DelayCompatible[Count] and I.DelayCompatible[Log] and I.GuaranteeCompatible[I.Delayed[Count], I.Delayed[Log]]:
    return on_cancel[I](delay[I](Count(calls.copy())), delay[I](Log(log.copy(), 3)))


def canceled_body[I: Defer & Cancel](log: ArcPointer[List[Int]]) -> I.Guaranteed[I.Canceled, I.Delayed[Log]] where I.DelayCompatible[Log] and I.GuaranteeCompatible[I.Canceled, I.Delayed[Log]]:
    return guarantee[I](canceled[I](), delay[I](Log(log.copy(), 4)))


def reset(calls: ArcPointer[Int], log: ArcPointer[List[Int]]):
    calls[] = 0
    log[].clear()


def laws_hold[sync: Bool]():
    var calls = ArcPointer(0)
    var log = ArcPointer(List[Int]())

    # uncancelable(poll => poll(fa)) == fa
    var restored: Int
    var direct: Int
    comptime if sync:
        restored = summary(run_io(poll_identity[SyncIO[Int]](calls)))
        reset(calls, log)
        direct = summary(run_io(plain[SyncIO[Int]](calls)))
    else:
        restored = summary(run(poll_identity[Async[Int]](calls)))
        reset(calls, log)
        direct = summary(run(plain[Async[Int]](calls)))
    check(restored == direct and calls[] == 1, "uncancelable(poll => poll(fa)) equals fa")

    # guarantee(fa, f) == fa, running f once
    reset(calls, log)
    var guarded_value: Int
    comptime if sync:
        guarded_value = summary(run_io(guarded[SyncIO[Int]](calls, log)))
    else:
        guarded_value = summary(run(guarded[Async[Int]](calls, log)))
    check(guarded_value == 10 and len(log[]) == 1, "guarantee keeps the outcome and finalizes once")

    # Finalizers run innermost first.
    reset(calls, log)
    comptime if sync:
        _ = run_io(nested[SyncIO[Int]](calls, log))
    else:
        _ = run(nested[Async[Int]](calls, log))
    check(len(log[]) == 2 and log[][0] == 1 and log[][1] == 2, "nested finalizers run innermost first")

    # on_cancel(fa, f) == fa without cancellation, and f never runs.
    reset(calls, log)
    var unobserved_value: Int
    comptime if sync:
        unobserved_value = summary(run_io(unobserved[SyncIO[Int]](calls, log)))
    else:
        unobserved_value = summary(run(unobserved[Async[Int]](calls, log)))
    check(unobserved_value == 10 and len(log[]) == 0, "on_cancel without cancellation equals its body")

    # guarantee(canceled, f) is canceled and runs f once.
    reset(calls, log)
    var was_canceled: Bool
    comptime if sync:
        was_canceled = not run_io(canceled_body[SyncIO[Int]](log))
    else:
        was_canceled = not run(canceled_body[Async[Int]](log))
    check(was_canceled and len(log[]) == 1 and log[][0] == 4, "a canceled body is finalized once")


@fieldwise_init
struct Recover(OnceUnary):
    """Recover from a failure, recording the errors it held."""
    var seen: ArcPointer[List[Int]]
    comptime Arg = EffectFailure[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var failure: EffectFailure[Int]) -> IO[Int, Int]:
        self.seen[].append(len(failure.errors))
        self.seen[].append(failure.errors.first())
        self.seen[].append(Int(failure.canceled))
        return IO[Int, Int].pure(0)


def main():
    laws_hold[True]()
    laws_hold[False]()
    # raise_error(e).handle_error_with(h) == h(EffectFailure([e], canceled=False))
    var seen = ArcPointer(List[Int]())
    var recovered = run(raise_error[Async[Int], Int](Int(5)).handle_error_with(Recover(seen.copy())))
    check(summary(recovered^) == 0 and len(seen[]) == 3 and seen[][0] == 1 and seen[][1] == 5 and seen[][2] == 0, "raise then recover sees one uncanceled error")
    print("cancel laws: poll identity, guarantee, finalizer order, on_cancel, canceled bodies, raise and recover")
