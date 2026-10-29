# error: cannot implicitly convert
# error: origin_of(other)
from algebra_support.post_traversal_contracts import flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int,origin_of(other)]]]:
    comptime View = Span[Int,origin_of(owner)]
    def callback(var value: Int) {owner} -> Optional[List[View]]: return Optional(List[View]([Span(owner)]))
    return flattened[ListFamily,OptionalFamily](List[Int]([1]),as_unary(callback))
def main():
    _ = wrong([1],[2])
