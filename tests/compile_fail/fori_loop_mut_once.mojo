# error: no matching function in call to 'fori_loop_mut'
from fp.control import fori_loop_mut
from fp.callables import OnceBinary
@fieldwise_init
struct Step(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var index: Int, var carry: Int) -> Int: return carry + index
def main():
    var body = Step()
    _ = fori_loop_mut(0, 3, body, 0)
