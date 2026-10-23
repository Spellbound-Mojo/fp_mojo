# error: constraint
from fp.data import Ior, Right
from fp.algebra import IorFamily, ListMonoid, product
def check(left: List[Int], right: List[Int]):
    comptime E = List[Span[Int, origin_of(left)]]
    comptime Other = List[Span[Int, origin_of(right)]]
    _ = product[IorFamily[ListMonoid[Span[Int, origin_of(left)]]]](Ior[E, Int](Right(1)), Ior[Other, Int](Right(2)))
def main(): check(List[Int]([1]), List[Int]([2]))
