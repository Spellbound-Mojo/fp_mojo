# error: no matching function in call to 'while_loop_mut'
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var carry: Int) -> Int: return carry + 1
def below(value: Int) -> Bool: return value < 4
def main(): _ = while_loop_mut(below, Step(), 0)
