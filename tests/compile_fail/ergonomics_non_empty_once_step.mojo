# error: no matching
from fp.iteration import reduce_non_empty
from fp.data import NonEmptyList
from fp.callables import OnceBinary
@fieldwise_init
struct OnlyOnce(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var a: Int, var b: Int) -> Int: return a + b
def main(): _ = reduce_non_empty(NonEmptyList(1,[2,3]), OnlyOnce())
