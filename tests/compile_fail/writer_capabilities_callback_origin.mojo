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
struct Same[o: ImmOrigin](OnceUnary, Defaultable):
    comptime Arg = Optional[Span[Int, Self.o]]
    comptime Out = Self.Arg
    def call_once(deinit self, var log: Self.Arg) -> Self.Out: return log^
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[Log[origin_of(left)]]
    comptime C = LiftCensor[StateT[W, Int], W]
    _ = censor[C](Same[origin_of(right)](), tell[C](Optional(Span(left))))
def main(): bad([1], [2])
