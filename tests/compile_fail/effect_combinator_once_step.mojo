# error: callbacks must be repeatable
from fp.iteration import iterated
from fp.algebra import OptionalFamily
from fp.callables import OnceBinary
@fieldwise_init
struct EFOnceStep(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Optional[Int]
    def call_once(deinit self,var a: Int,var b: Int) -> Self.Out: return Optional(a+b)
def main(): _ = iterated(range(2)).fold_effect[OptionalFamily](EFOnceStep(),0)
