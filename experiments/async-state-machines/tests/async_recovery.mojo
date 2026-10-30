"""Failure ownership transfers only at admitted recovery-handler entry."""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.algebra import ErrorRecovery, ApplicativeError
from fp.effects import EffectFailure
from fp.effects._async.engine import IO, Async
from fp.effects._async.finalization import Poll
from fp.effects._async.kernel import run
from foundation import check
from recovery_support import source


@fieldwise_init
struct Handler(OnceUnary):
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = EffectFailure[Int]
    comptime Out = IO[Int, Int]
    comptime Error = Int
    def call_once(deinit self, var failure: Self.Arg) raises Int -> Self.Out:
        self.calls[] += 1
        check(not failure.canceled, "canceled failures must bypass the handler")
        var errors = failure^.into_errors().into_list()
        check(len(errors) == 2 and errors[0] == 11 and errors[1] == 22, "handler must receive every error in order")
        if self.fail:
            raise 99
        return IO[Int, Int].pure(7)


@fieldwise_init
struct Masked(OnceUnary):
    var body: IO[Int, Int]
    comptime Arg = Poll[Int]
    comptime Out = IO[Int, Int]
    def call_once(deinit self, var poll: Poll[Int]) -> IO[Int, Int]:
        return self.body^


def main():
    comptime assert conforms_to(Async[Int], ErrorRecovery)
    comptime assert not conforms_to(Async[Int], ApplicativeError)
    for mode in range(4):
        var calls = ArcPointer(0)
        var outcome = run(source(mode).handle_error_with(Handler(calls.copy(), False)))
        check(calls[] == (1 if mode == 2 else 0), "recover only noncanceled errors")
        if mode == 1:
            check(not outcome, "cancellation-only remains terminal")
        elif mode == 3:
            var failure = outcome.take()._take_err()
            check(failure.canceled and len(failure.errors) == 2, "canceled failure retains all errors")
        else:
            check(outcome.take()._take_ok() == (7 if mode == 2 else 42), "recovery preserves success or returns handler result")
    var calls = ArcPointer(0)
    var replacement = run(source(2).handle_error_with(Handler(calls.copy(), True)))
    var failure = replacement.take()._take_err()
    check(len(failure.errors) == 1 and failure.errors.first() == 99, "handler failure replaces the transferred failure")
    calls[] = 0
    var canceled = run(source(2, True).handle_error_with(Handler(calls.copy(), False)))
    var retained = canceled.take()._take_err()
    check(calls[] == 0 and retained.canceled and len(retained.errors) == 2, "a failure observed with cancellation requested keeps its errors and bypasses recovery")
    var protected = run(IO[Int, Int].uncancelable(Masked(source(0, True))).handle_error_with(Handler(calls.copy(), False)))
    check(protected.take()._take_ok() == 42 and calls[] == 0, "recovery bypass preserves protected terminal success")
    print("recovery: success bypass, complete errors, cancellation boundary, replacement, protected success")
