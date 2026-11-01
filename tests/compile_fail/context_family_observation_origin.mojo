# error: invalid call to 'flat_tap_err': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.effects import Reader, ResultT
from fp.data import Result, Err
from fp.callables import BorrowCallable
@fieldwise_init
struct Different[L:Movable & Deinitable,R:Copyable & Movable & Deinitable](BorrowCallable):
    var replacement:Self.R
    comptime Payload=Self.L
    comptime Result=Result[Int,Self.R]
    def invoke(self,ref error:Self.L) capturing -> Self.Result:return Err(self.replacement)
def reject(left:List[Int],right:List[Int]):
    comptime Left=type_of(Span(left))
    _ = pipeline(Result[Int,Left](Err(Span(left)))).flat_tap_err(Different[Left,type_of(Span(right))](Span(right))).get()
def main():
    var left=List[Int]([1])
    var right=List[Int]([2])
    reject(left,right)
