# error: cannot implicitly convert
# error: origin_of(other)
from algebra_support.post_traversal_contracts import flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int],Span[Int,origin_of(other)]]:
    var failure = Span(owner)
    comptime Failure = type_of(failure)
    def callback(var value: Int) {failure} -> Result[List[Int],Failure]: return Err(failure)
    return flattened[ListFamily,ResultFamily[Failure]](List[Int]([1]),as_unary(callback))
def main():
    _ = wrong([1],[2])
