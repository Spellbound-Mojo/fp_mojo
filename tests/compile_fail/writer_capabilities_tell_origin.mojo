# error: cannot be converted
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
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[Log[origin_of(left)]]
    comptime C = LiftCensor[ReaderT[W, Int], W]
    _ = tell[C](Optional(Span(right)))
def main(): bad([1], [2])
