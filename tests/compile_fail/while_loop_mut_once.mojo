# error: no matching function in call to 'while_loop_mut'
from fp.control import while_loop_mut
from fp.callables import OnceUnary
@fieldwise_init
struct Step(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var carry: Int) -> Int: return carry + 1
def below(value: Int) -> Bool: return value < 4
def main():
    var body = Step()
    _ = while_loop_mut(below, body, 0)
