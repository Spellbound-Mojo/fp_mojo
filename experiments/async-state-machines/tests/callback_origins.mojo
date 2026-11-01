"""Callback captures, values, errors and retained handles keep native origins."""
from fp.callables import OnceUnary
from state_machine import Completion, callback, pure, run
from foundation import success, check


@fieldwise_init
struct BorrowRegister[o: ImmOrigin](OnceUnary):
    var owner: Pointer[List[Int], Self.o]
    var fail: Bool
    comptime View = Span[Int, Self.o]
    comptime Arg = Completion[Self.View, Self.View]
    comptime Out = NoneType
    comptime Error = Self.View
    def call_once(deinit self, var done: Self.Arg) raises Self.View -> NoneType:
        if self.fail:
            raise Span(self.owner[])
        check(done.complete(success[Self.View, Self.View](Span(self.owner[]))._outcome()), "borrowed value accepted")
        return None


def exercise[o: ImmOrigin](ref[o] owner: List[Int]):
    var unit: NoneType = None
    var succeeded = run(callback(BorrowRegister(Pointer(to=owner), False), pure[Span[Int, o]](unit)))
    check(succeeded.take()._take_ok()[1] == 17, "borrowed value survives callback cleanup")
    var failed = run(callback(BorrowRegister(Pointer(to=owner), True), pure[Span[Int, o]](unit)))
    var error = failed.take()._take_err()
    check(error.errors.first()[0] == 13 and not error.canceled, "borrowed registration failure retains origin")


def main():
    var owner = List[Int]([13, 17])
    exercise(owner)
    print("callback origins: borrowed capture, result and registration error")
