# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct Observer[V: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.V
    comptime Result = Optional[Bool]
    def invoke(self, ref value: Self.V) capturing -> Self.Result: return Optional(True)
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    comptime Actual = type_of(view)
    comptime Expected = type_of(Span(anchor))
    _ = pipeline(List[Actual]([view])).filter_effect[OptionalFamily](Observer[Expected]()).get()
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
