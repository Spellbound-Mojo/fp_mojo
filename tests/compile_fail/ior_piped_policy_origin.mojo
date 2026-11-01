# error: constraint
from fp.data import Ior, Right
from fp.algebra import IorFamily, ListMonoid
from fp.functions import pipeline
def check(left: List[Int], right: List[Int]):
    comptime Other = List[Span[Int, origin_of(right)]]
    def next_step(value: Int) -> Ior[Other, Int]: return Right(value)
    comptime E = List[Span[Int, origin_of(left)]]
    _ = pipeline[IorFamily[ListMonoid[Span[Int, origin_of(left)]]]](Ior[E, Int](Right(1))).flat_map(next_step)
def main(): check(List[Int]([1]), List[Int]([2]))
