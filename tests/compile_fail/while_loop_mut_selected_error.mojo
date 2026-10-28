# error: while_loop_mut: selected error must match the exact combined error
from fp.control import while_loop_mut
from fp.callables import MutableUnary, BorrowSignature
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int: return value + 1
def below(value: Int) -> Bool: return value < 4
def main() raises:
    var body = Step()
    _ = while_loop_mut[E=Int](BorrowSignature[Int, Bool].capture(below), body, 0)
