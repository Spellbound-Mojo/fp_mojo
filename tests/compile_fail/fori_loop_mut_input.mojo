# error: no matching function in call to 'fori_loop_mut'
from fp.control import fori_loop_mut
from fp.callables import MutableBinary
@fieldwise_init
struct Step(MutableBinary):
    comptime First = Int
    comptime Second = String
    comptime Out = Int
    def call_mut(mut self, var index: Int, var carry: String) -> Int: return index
def main():
    var body = Step()
    _ = fori_loop_mut(0, 3, body, 0)
