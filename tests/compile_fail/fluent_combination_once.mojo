# error: no matching method in call to 'map2'
from fp.functions import pipeline
from fp.callables import OnceBinary
@fieldwise_init
struct FCOnce(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var first: Int, var second: Int) -> Int: return first + second
def main():
    var left: List[Int] = [1, 2]
    var right: List[Int] = [3]
    _ = pipeline(left^).map2(right^, FCOnce())
