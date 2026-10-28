# error: use of uninitialized value 'body'
from fp.control import fori_loop_mut
from fp.callables import MutableBinary
@fieldwise_init
struct Step(MutableBinary):
    var capture: String
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_mut(mut self, var index: Int, var carry: Int) -> Int: return carry + index + self.capture.byte_length()
def main():
    var body = Step(String("owned"))
    var moved = body^
    _ = fori_loop_mut(0, 3, body, 0)
    _ = moved^
