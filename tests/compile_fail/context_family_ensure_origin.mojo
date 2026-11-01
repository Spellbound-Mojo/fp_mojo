# error: invalid call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct Make[V: Copyable & Deinitable](BorrowCallable):
    var owner: Self.V
    comptime Payload = Int
    comptime Result = Self.V
    def invoke(self, ref value: Int) -> Self.Result: return self.owner.copy()
def predicate(value: Int) -> Bool: return False
def reject(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    _ = pipeline(Result[Int,Left](Ok(1))).ensure(predicate,Make(Span(right)))
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    reject(left,right)
