# error: constraint
from fp.data import Ior, Both
from fp.algebra import map, IorFamily, ListMonoid
from fp.functions import Identity
def check(left: List[Int], right: List[Int]):
    comptime E = List[Span[Int, origin_of(left)]]
    comptime Other = List[Span[Int, origin_of(right)]]
    var issues = Other([Span(right)])
    _ = map[IorFamily[ListMonoid[Span[Int, origin_of(left)]]]](Ior[Other, Int](Both(issues^, 1)), Identity[Int]())
def main():
    check(List[Int]([1]), List[Int]([2]))
