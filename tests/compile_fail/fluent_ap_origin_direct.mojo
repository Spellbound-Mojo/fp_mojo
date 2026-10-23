# error: constraint
from fp.functions import piped
from fp.data import Result, Ok
from fp.callables import Unary
@fieldwise_init
struct APView[o: ImmOrigin](Unary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Int
    def call(self, var arg: Self.Arg) -> Int: return arg[0]
def mismatch(left: List[Int],right: List[Int]):
    _ = Result[APView[origin_of(left)],String](Ok(APView[origin_of(left)]())).ap(Result[Span[Int,origin_of(right)],String](Ok(Span(right))))
def main(): mismatch([1],[2])
