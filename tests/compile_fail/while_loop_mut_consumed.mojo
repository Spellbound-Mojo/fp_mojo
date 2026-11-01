# error: use of uninitialized value 'body'
from fp.control import while_loop_mut
from fp.callables import MutableUnary
@fieldwise_init
struct Step(MutableUnary):
    var capture: String
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var carry: Int) -> Int: return carry + 1 + self.capture.byte_length()
def below(value: Int) -> Bool: return value < 4
def main():
    var body = Step(String("owned"))
    var moved = body^
    _ = while_loop_mut(below, body, 0)
    _ = moved^
