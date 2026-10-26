# error: invalid call to 'attempt_tap': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
from fp.callables import BorrowCallable
@fieldwise_init
struct Different[L:Movable & Deinitable,R:Copyable & Deinitable](BorrowCallable):
    var replacement:Self.R
    comptime Payload=Result[Int,Self.L]
    comptime Result=Result[Int,Self.R]
    def invoke(self,ref outcome:Self.Payload) capturing -> Self.Result:return Err(self.replacement)
def reject(left:List[Int],right:List[Int]):
    comptime Left=type_of(Span(left))
    _ = pipeline(Result[Int,Left](Err(Span(left)))).attempt_tap(Different[Left,type_of(Span(right))](Span(right))).get()
def main():
    reject(List[Int]([1]),List[Int]([2]))
