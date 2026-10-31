# error: constraint
from fp.data import Ior, Right
from fp.algebra import ListFamily, IorFamily, StringMonoid, traverse
from fp.callables import Unary
@fieldwise_init
struct Step[o: ImmOrigin](Unary, Copyable):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Ior[String, Span[Int, Self.o]]
    def call(self, var value: Self.Arg) -> Self.Out: return Right(value)
def check(left: List[Int], right: List[Int]):
    comptime Other = Span[Int, origin_of(right)]
    _ = traverse[IorFamily[StringMonoid], ListFamily](List[Other]([Span(right)]), Step[origin_of(left)]())
def main(): check(List[Int]([1]), List[Int]([2]))
