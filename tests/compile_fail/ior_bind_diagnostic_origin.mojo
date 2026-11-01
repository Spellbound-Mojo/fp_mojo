# error: constraint
from fp.data import Ior, Right, Both
from fp.algebra import flat_map, IorFamily, ListMonoid
def check(left: List[Int], right: List[Int]):
    comptime E = List[Span[Int, origin_of(left)]]
    comptime Other = List[Span[Int, origin_of(right)]]
    var borrowed = Span(right)
    def next_step(value: Int) -> Ior[Other, Int]:
        var issues = Other([borrowed])
        return Both(issues^, value)
    _ = flat_map[IorFamily[ListMonoid[Span[Int, origin_of(left)]]]](Ior[E, Int](Right(1)), next_step)
def main():
    check(List[Int]([1]), List[Int]([2]))
