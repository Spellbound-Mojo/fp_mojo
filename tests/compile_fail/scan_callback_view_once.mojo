# error: no matching method
from fp.functions import flip
from fp.iteration import iterated
from fp.callables import OnceBinary
@fieldwise_init
struct Once(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int, Int]
    def call_once(deinit self, var first: Int, var second: Int) -> Self.Out: return (first, second)
def main():
    var callback = flip(Once())
    _ = iterated(range(2)).scan_map(callback^, 0)
