# error: constraint
from fp.data import Ior, Right
from fp.algebra import IorFamily, Semigroup, flat_map
struct IOOriginPolicy[o: ImmOrigin](Semigroup):
    comptime Value = String
    comptime Error = Span[Int, Self.o]
    @staticmethod
    def combine(var left: String, var right: String) raises Self.Error -> String: return left^
def check(left: List[Int], right: List[Int]):
    def step(value: Int) raises Span[Int, origin_of(right)] -> Ior[String, Int]: return Right(value)
    _ = flat_map[IorFamily[IOOriginPolicy[origin_of(left)]]](Ior[String, Int](Right(1)), step)
def main(): check(List[Int]([1]), List[Int]([2]))
