# error: constraint failed
# error: comptime assert Self.Item == ControlFlow[Self.Value, Self.F.Arg]
from fp.callables import MutableUnary
from fp.data import ControlFlow, Break
from state_machine import Pure, pure, loop, run

@fieldwise_init
struct Wrong(MutableUnary):
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, String], Int]
    def call_mut(mut self, var value: Int) -> Self.Out:
        return pure[Int](ControlFlow[Int, String](Break(value)))

def main():
    _ = run(loop(0, Wrong()))
