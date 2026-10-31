# error: constraint
from fp.functions import pipeline
from fp.callables import Unary
@fieldwise_init
struct APView[o: ImmOrigin](Unary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Int
    def call(self, var arg: Self.Arg) -> Int: return arg[0]
def mismatch(left: List[Int],right: List[Int]):
    _ = pipeline(Optional(APView[origin_of(left)]())).ap(Optional(Span(right)))
def main(): mismatch([1],[2])
