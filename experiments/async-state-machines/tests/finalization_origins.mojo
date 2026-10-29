from fp.callables import OnceUnary
from fp.effects import ExitCase, IOContext
from state_machine import ScopedMachine, Step, Wait, Pure, Poll, guarantee_case, uncancelable_with, pure, run
from foundation import Borrowed, check, success


@fieldwise_init
struct BorrowExit[o: ImmOrigin](ScopedMachine):
    var owner: Pointer[List[Int], Self.o]
    var phase: Int
    comptime View = Span[Int, Self.o]
    comptime Input = ExitCase[Self.View]
    comptime Value = Self.View
    comptime Error = Self.View
    def poll[p: ImmOrigin](mut self, ref[p] exit: Self.Input, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        check(context._masked, "borrowed finalizer masked")
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        if exit.is_error():
            check(exit.failure().value().errors.first()[0] == 13, "borrow original error across suspension")
        return success[Self.Value, Self.Error](Span(self.owner[]))


@fieldwise_init
struct Factory[o: ImmOrigin](OnceUnary):
    var owner: Pointer[List[Int], Self.o]
    var fail: Bool
    comptime View = Span[Int, Self.o]
    comptime Arg = Poll[Self.View]
    comptime Out = Poll[Self.View].Applied[Borrowed[Self.o]]
    comptime Error = Self.View
    def call_once(deinit self, var poll: Self.Arg) raises Self.Error -> Self.Out:
        if self.fail:
            raise Span(self.owner[])
        return poll.apply(Borrowed(self.owner, 0, False))


def exercise[o: ImmOrigin](ref[o] owner: List[Int]):
    var success_result = run(guarantee_case(Borrowed(Pointer(to=owner), 0, False), BorrowExit(Pointer(to=owner), 0)))
    check(success_result.take()._take_ok()[1] == 17, "body result retains external origin")
    var failed = run(guarantee_case(Borrowed(Pointer(to=owner), 0, True), BorrowExit(Pointer(to=owner), 0)))
    check(failed.take()._take_err().errors.first()[0] == 13, "borrowed body error retained")
    var masked = run(uncancelable_with[Span[Int, o]](Factory(Pointer(to=owner), False)))
    check(masked.take()._take_ok()[1] == 17, "masked factory and restored result preserve origin")
    var factory_failed = run(uncancelable_with[Span[Int, o]](Factory(Pointer(to=owner), True)))
    check(factory_failed.take()._take_err().errors.first()[0] == 13, "factory retains exact borrowed error")


def main():
    var owner = List[Int]([13, 17])
    exercise(owner)
    print("finalization origins: scoped exits, body values/errors, masked factories and restored results")
