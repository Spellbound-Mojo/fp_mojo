# error: control: full unrolling requires static bounds
from fp.control import fori_loop
from fp.callables import MutableBinary
@fieldwise_init
struct Step(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_mut(mut self, var index: Int, var carry: Int) -> Int: return carry + index
def main():
    var body = Step()
    _ = fori_loop[unroll=0](0, 3, body^, 0)
