# error: constraint failed
# error: comptime assert RepeatableUnary[Self.F]
from fp.callables import OnceUnary
from fp.data import ControlFlow, Break
from state_machine import Pure, pure, loop, run

@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, Int], Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return pure[Int](ControlFlow[Int, Int](Break(value)))

def main():
    _ = run(loop(0, Once()))
