# error: constraint
from fp.algebra import Monoid
from fp.effects import Writer, ReaderT, StateT, ResultT, LiftCensor, tell, listen, censor
from fp.callables import OnceUnary
struct Log[o: ImmOrigin](Monoid):
    comptime Value = Optional[Span[Int, Self.o]]
    @staticmethod
    def empty() -> Self.Value: return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        if right: return right^
        return left^
@fieldwise_init
struct Change[a: ImmOrigin, b: ImmOrigin](OnceUnary):
    var other: Optional[Span[Int, Self.b]]
    comptime Arg = Optional[Span[Int, Self.a]]
    comptime Out = Optional[Span[Int, Self.b]]
    def call_once(deinit self, var log: Self.Arg) -> Self.Out: return self.other^
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[Log[origin_of(left)]]
    comptime C = LiftCensor[ReaderT[W, Int], W]
    _ = censor[C](Change[origin_of(left), origin_of(right)](Optional(Span(right))), tell[C](Optional(Span(left))))
def main(): bad([1], [2])
