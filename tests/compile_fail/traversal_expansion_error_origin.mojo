# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct TXRejectedError[o: ImmOrigin](BorrowCallable):
    var error: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = Span[Int, Self.o]
    def invoke(self, ref value: Int) raises Self.Failure capturing -> Self.Result:
        raise self.error
def mismatch(left: List[Int], right: List[Int]):
    var xs: List[Int] = [1]
    try: _ = piped(xs^).filter_effect[OptionalFamily, X=Span[Int, origin_of(right)]](TXRejectedError(Span(left)))
    except: pass
def main(): mismatch([1], [2])
