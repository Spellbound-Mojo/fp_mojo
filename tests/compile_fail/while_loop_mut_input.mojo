# error: no matching function in call to 'while_loop_mut'
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = String
    comptime Out = Int
    def call_mut(mut self, var carry: String) -> Int: return 0
def below(value: Int) -> Bool: return value < 4
def main():
    var body = Step()
    _ = while_loop_mut(below, body, 0)
