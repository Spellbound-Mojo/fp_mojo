"""A protected terminal value survives forwarding, but not a new operation."""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.effects import IOContext, CancellationToken, EffectFailure
from fp.data import Result, Err, NonEmptyList
from state_machine import Machine, Step, Pure, Masked, bind, pure, run, uncancelable
from state_machine.finalization import _ConstantMask
from foundation import check, success


@fieldwise_init
struct RequestAndFinish(Machine):
    var fail: Bool
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        context.request_cancel()
        if self.fail:
            return .ready(Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(17), False)))))
        return success[Int, Int](42)


@fieldwise_init
struct CountNext(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Pure[Int, Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        self.calls[] += 1
        return pure[Int](value + 1)


@fieldwise_init
struct MaskNext(OnceUnary):
    comptime Arg = Int
    comptime Out = Masked[_ConstantMask[RequestAndFinish], Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return uncancelable(RequestAndFinish(False))


def main():
    check(not run(RequestAndFinish(False)), "unmasked completion observes cancellation")
    var protected = run(uncancelable(RequestAndFinish(False)))
    check(protected.take()._take_ok() == 42, "masked success is not discarded at the owner boundary")
    var forwarded = run(bind(pure[Int](0), MaskNext()))
    check(forwarded.take()._take_ok() == 42, "bind forwards its terminal child's protected result")
    var calls = ArcPointer(0)
    var chained = run(bind(uncancelable(RequestAndFinish(False)), CountNext(calls.copy())))
    check(not chained and calls[] == 0, "a new continuation observes the pending request")
    var failure_outcome = run(uncancelable(RequestAndFinish(True)))
    var failed = failure_outcome.take()._take_err()
    check(failed.canceled and failed.errors.first() == 17, "protection never discards error or cancellation information")
    var token = CancellationToken()
    token.cancel()
    check(not run(uncancelable(pure[Int](1)), token), "an unopened masked recipe does not bypass entry cancellation")
    print("checkpoints: protected success, forwarding, new work, failures, entry cancellation")
