# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.functions import pipeline
from fp.callables import BorrowCallable
@fieldwise_init
struct ExpectedObserver[V: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.V
    comptime Result = Bool
    def invoke(self, ref value: Self.V) capturing -> Self.Result: return True
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime Actual = type_of(actual)
    comptime Expected = type_of(Span(anchor))
    _ = pipeline(List[Actual]([actual])).filter_not(ExpectedObserver[Expected]()).get()
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
