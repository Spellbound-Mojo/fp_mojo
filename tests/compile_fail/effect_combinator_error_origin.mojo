# A library callable keeps its exact error origin; it cannot escape as another origin.
# error: cannot call function that may raise
# error: in context that supports an error type of 'Span[Int, origin_of(right)]'
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct EFErrorOrigin[o: ImmOrigin](BorrowCallable):
    var error: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = Span[Int, Self.o]
    def invoke(self, ref x: Int) raises Self.Failure capturing -> Self.Result: raise self.error
def mismatch(left: List[Int],right: List[Int]) raises Span[Int,origin_of(right)]:
    var xs: List[Int] = [1]
    _ = pipeline(xs^).any_effect[OptionalFamily](EFErrorOrigin(Span(left)))
def main():
    var left: List[Int] = [1]
    var right: List[Int] = [2]
    try: mismatch(left, right)
    except: pass
