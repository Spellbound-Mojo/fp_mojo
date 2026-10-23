# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct EFErrorOrigin[o: ImmOrigin](BorrowCallable):
    var error: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = Span[Int, Self.o]
    def invoke(self, ref x: Int) raises Self.Failure capturing -> Self.Result: raise self.error
def mismatch(left: List[Int],right: List[Int]):
    var xs: List[Int] = [1]
    try: _ = piped(xs^).any_effect[OptionalFamily, X=Span[Int,origin_of(right)]](EFErrorOrigin(Span(left)))
    except: pass
def main(): mismatch([1],[2])
