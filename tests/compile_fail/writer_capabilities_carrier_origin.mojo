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
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[Log[origin_of(left)]]
    comptime Other = Writer[Log[origin_of(right)]]
    comptime C = LiftCensor[ResultT[W, String], W]
    _ = listen[C](tell[LiftCensor[ResultT[Other, String], Other]](Optional(Span(right))))
def main(): bad([1], [2])
