"""IO sequencing, recovery, and masking laws as observable equations.

Finalizer ordering and exact exits are covered by io_finalization; attempt laws
follow once IO joins the Async family.
"""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.data import NonEmptyList
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from state_machine import IO, Machine, Step, Wait, Task, Poll, run
from foundation import check, success, Failure


def new_stats() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]([0, 0, 0, 0, 0]))


@fieldwise_init
struct Times(OnceUnary):
    var factor: Int
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value * self.factor)


@fieldwise_init
struct Plus(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value + self.amount)


@fieldwise_init
struct Pure(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value)


@fieldwise_init
struct TimesThenPlus(OnceUnary):
    """The right side of associativity: x => times(x).flat_map(plus)."""
    var factor: Int
    var amount: Int
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value * self.factor).flat_map(Plus(self.amount))


@fieldwise_init
struct Handler(OnceUnary):
    """Encode what recovery received: errors, first code, and the canceled flag."""
    var invoked: ArcPointer[List[Int]]
    comptime Arg = EffectFailure[Failure]
    comptime Out = IO[Int, Failure]

    def __deinit__(deinit self):
        self.invoked[][1] += 1

    def call_once(deinit self, var failure: EffectFailure[Failure]) -> IO[Int, Failure]:
        self.invoked[][0] += 1
        var canceled = failure.canceled
        var errors = failure^.into_errors().into_list()
        return IO[Int, Failure].pure(len(errors) * 1000 + errors[0].code * 10 + Int(canceled))


@fieldwise_init
struct Work(Machine):
    var id: Int
    var remaining: Int
    comptime Value = Int
    comptime Error = Failure

    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        if context.canceled():
            return .ready(None)
        if self.remaining > 0:
            self.remaining -= 1
            return .pending(Wait())
        return success[Int, Failure](self.id)


@fieldwise_init
struct Restore(OnceUnary):
    var body: IO[Int, Failure]
    comptime Arg = Poll[Failure]
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var poll: Poll[Failure]) -> IO[Int, Failure]:
        return self.body^.restore(poll)


@fieldwise_init
struct Ignore(OnceUnary):
    var body: IO[Int, Failure]
    comptime Arg = Poll[Failure]
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var poll: Poll[Failure]) -> IO[Int, Failure]:
        return self.body^


def value(var io: IO[Int, Failure]) -> Int:
    var outcome = run(io^)
    return outcome.take()._take_ok()


def canceled_after_one_tick(var io: IO[Int, Failure]) -> Outcome[Int, Failure]:
    var task = Task(io^, CancellationToken())
    _ = task.tick()
    task.cancel()
    while not task.done():
        _ = task.tick()
    return task^.finish()


def monad_laws():
    check(value(IO[Int, Failure].pure(6).flat_map(Times(7))) == value(Times(7).call_once(6)), "left identity")
    check(value(IO[Int, Failure].lift(Work(5, 2)).flat_map(Pure())) == value(IO[Int, Failure].lift(Work(5, 2))), "right identity")
    var left = IO[Int, Failure].lift(Work(3, 1)).flat_map(Times(4)).flat_map(Plus(5))
    var right = IO[Int, Failure].lift(Work(3, 1)).flat_map(TimesThenPlus(4, 5))
    check(value(left^) == value(right^), "associativity")


def recovery_laws():
    var stats = new_stats()
    var direct = Handler(ArcPointer(List[Int]([0, 0]))).call_once(EffectFailure[Failure](NonEmptyList(Failure(7, stats.copy())), False))
    var invoked = ArcPointer(List[Int]([0, 0]))
    var recovered = IO[Int, Failure].raise_error(Failure(7, stats.copy())).handle_error_with(Handler(invoked.copy()))
    check(value(recovered^) == value(direct^), "handle_error_with(raise_error(e), h) equals h(failure of e)")
    check(invoked[][0] == 1, "the handler ran once on an uncanceled single failure")
    var skipped = ArcPointer(List[Int]([0, 0]))
    check(value(IO[Int, Failure].pure(4).handle_error_with(Handler(skipped.copy()))) == 4, "handle_error_with(pure(a), h) equals pure(a)")
    check(skipped[][0] == 0 and skipped[][1] == 1, "the skipped handler dropped unopened")


def canceled_failures_bypass_recovery():
    var stats = new_stats()
    var invoked = ArcPointer(List[Int]([0, 0]))
    var io = IO[Int, Failure].lift(Work(1, 100)).on_cancel(IO[NoneType, Failure].raise_error(Failure(8, stats.copy()))).handle_error_with(Handler(invoked.copy()))
    var outcome = canceled_after_one_tick(io^)
    var failure = outcome.take()._take_err()
    check(failure.canceled and invoked[][0] == 0, "a failure with cancellation bypasses recovery")
    check(failure^.into_errors().into_list()[0].code == 8, "the cleanup error is retained")


def masking_laws():
    check(value(IO[Int, Failure].uncancelable(Restore(IO[Int, Failure].lift(Work(6, 2))))) == value(IO[Int, Failure].lift(Work(6, 2))), "uncancelable(poll => poll(fa)) equals fa")
    var restored = canceled_after_one_tick(IO[Int, Failure].uncancelable(Restore(IO[Int, Failure].lift(Work(6, 100)))))
    var plain = canceled_after_one_tick(IO[Int, Failure].lift(Work(6, 100)))
    check(not restored and not plain, "poll(fa) observes cancellation as fa does")
    var masked = canceled_after_one_tick(IO[Int, Failure].uncancelable(Ignore(IO[Int, Failure].lift(Work(6, 3)))))
    check(masked.take()._take_ok() == 6, "a masked success survives cancellation")


def main():
    monad_laws()
    recovery_laws()
    canceled_failures_bypass_recovery()
    masking_laws()
    print("io laws: monad identities and associativity, raise and handle, canceled bypass, uncancelable poll identity, masked success")
