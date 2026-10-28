# error: no matching method in call to 'map_accumulate'
from fp.iteration import iterated
from fp.callables import OnceBinary
struct Step(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int,Int]
    def __init__(out self): pass
    def call_once(deinit self, var a: Int,var b: Int) -> Self.Out: return (a,b)
def main(): _ = iterated([1]).map_accumulate(Step(),0)
