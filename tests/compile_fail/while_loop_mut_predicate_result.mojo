# error: no matching function in call to 'while_loop_mut'
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int: return value + 1
def bad(value: Int) -> Int: return value
def main():
    var step = Step()
    _ = while_loop_mut(bad, step, 0)
