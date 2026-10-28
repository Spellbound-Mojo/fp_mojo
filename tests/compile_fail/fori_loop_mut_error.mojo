# error: cannot call function that may raise
from fp.control import fori_loop_mut
from fp.callables import MutableBinary
@fieldwise_init
struct Step(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var index: Int, var carry: Int) raises Int -> Int: raise index
def main():
    var body = Step()
    _ = fori_loop_mut(0, 3, body, 0)
