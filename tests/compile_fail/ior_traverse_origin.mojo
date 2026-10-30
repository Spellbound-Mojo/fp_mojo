# error: constraint
from fp.data import Ior, Right
from fp.algebra import IorValidationFamily, ListMonoid, ListFamily, traverse
def check(left: List[Int], right: List[Int]):
    comptime Other = List[Span[Int, origin_of(right)]]
    def step(value: Int) -> Ior[Other, Int]: return Right(value)
    _ = traverse[ListFamily, IorValidationFamily[ListMonoid[Span[Int, origin_of(left)]]]](List[Int]([1]), step)
def main(): check(List[Int]([1]), List[Int]([2]))
