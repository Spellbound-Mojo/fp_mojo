# error: no matching function in call to 'while_loop_mut'
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var value: Int) raises Int -> Int: return value + 1
def bad(value: Int) raises String -> Bool: raise String("bad")
def main() raises:
    var step = Step()
    _ = while_loop_mut(bad, step, 0)
