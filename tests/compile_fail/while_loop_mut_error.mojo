# error: cannot call function that may raise
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var carry: Int) raises Int -> Int: raise carry
def below(value: Int) -> Bool: return value < 4
def main():
    var body = Step()
    _ = while_loop_mut(below, body, 0)
