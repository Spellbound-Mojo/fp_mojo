# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int],Span[Int,origin_of(other)]]:
    var view = Span(owner)
    comptime Failure = type_of(view)
    def fail(var value: Int) {view} -> Result[List[Int],Failure]: return Err(view)
    return iterated(range(2)).flat_traverse(as_unary(fail))
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
