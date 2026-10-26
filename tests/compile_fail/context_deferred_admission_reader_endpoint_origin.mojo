# error: invalid call to 'action': lacking evidence to prove correctness
# error: EndpointCompatible
# error: origin_of(left)
# error: origin_of(right)
from fp.effects import ReaderT, action
from fp.algebra import ResultFamily
from fp.callables import BorrowCallable
from fp.data import Result, Err

@fieldwise_init
struct ReadError[T: Copyable & Deinitable](BorrowCallable):
    var error: Self.T
    comptime Payload = Int
    comptime Result = Result[Int, Self.T]
    def invoke(self, ref value: Int) raises Never capturing -> Self.Result:
        return Err(self.error.copy())

def check(left: List[Int], right: List[Int]):
    var expected = Span(left)
    var other = Span(right)
    comptime I = ReaderT[ResultFamily[type_of(expected)], Int]
    _ = action[I, Int](ReadError(other))

def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    check(left, right)
