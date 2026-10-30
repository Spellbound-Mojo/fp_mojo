"""Composed values and errors preserve independent external origins."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, MutableUnary
from fp.data import ControlFlow, Continue, Break
from fp.effects import IOContext, ExitCase
from state_machine import ScopedMachine, CleanupMachine, Scope, Step, Wait, Pure, pure, bind, loop, run
from foundation import Borrowed, check, success, Resource, Failure, both


@fieldwise_init
struct Identity[o: ImmOrigin](OnceUnary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Pure[Self.Arg, Self.Arg]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out:
        return pure[Self.Arg](value)


@fieldwise_init
struct Repeat[o: ImmOrigin](MutableUnary):
    var calls: Int
    comptime Arg = Span[Int, Self.o]
    comptime Out = Pure[ControlFlow[Self.Arg, Self.Arg], Self.Arg]
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.calls += 1
        if self.calls == 3:
            return pure[Self.Arg](ControlFlow[Self.Arg, Self.Arg](Break(value)))
        return pure[Self.Arg](ControlFlow[Self.Arg, Self.Arg](Continue(value)))


def exercise[o: ImmOrigin, p: ImmOrigin](ref[o] owner: List[Int], ref[p] other: List[Int]):
    var sequenced = run(bind(Borrowed(Pointer(to=owner), 0, False), Identity[origin_of(owner)]()))
    check(sequenced.take()._take_ok()[1] == 17, "bind retains external origin")
    var repeated = run(loop(Span(owner), Repeat[origin_of(owner)](0)))
    check(repeated.take()._take_ok()[0] == 13, "loop retains borrowed state and result")
    var failed = run(both(Borrowed(Pointer(to=owner), 0, False), Borrowed(Pointer(to=owner), 0, True)))
    var error = failed.take()._take_err()
    check(error.errors.first()[0] == 13, "child borrowed error retains origin")
    print("origins: bind, loop, child errors")


def main():
    var owner = List[Int]([13, 17])
    var other = List[Int]([19, 23])
    exercise(owner, other)
