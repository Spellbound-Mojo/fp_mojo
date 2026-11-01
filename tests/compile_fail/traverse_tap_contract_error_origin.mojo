# error: cannot implicitly convert
# error: origin_of(other)
from algebra_support.tap_contracts import observed
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import BorrowSignature
from fp.data import Result,Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int],Span[Int,origin_of(other)]]:
    var view = Span(owner)
    comptime Failure = type_of(view)
    def fail(value: Int) {view} -> Result[Int,Failure]: return Err(view)
    return observed[ListFamily,ResultFamily[Failure]](range(2),BorrowSignature[Int,Result[Int,Failure]].capture(fail))
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
