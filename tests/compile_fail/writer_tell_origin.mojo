# error: cannot be converted
from fp.algebra import Monoid
from fp.effects import Writer, writer
from fp.functions import pipeline
struct Log[o: ImmOrigin](Monoid):
    comptime Value = Optional[Span[Int,Self.o]]
    @staticmethod
    def empty() -> Self.Value: return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value: return right^
def bad(left: List[Int], right: List[Int]):
    comptime W = Writer[Log[origin_of(left)]]
    _ = pipeline(writer[W,Int]((Optional(Span(left)),7))).tell(Optional(Span(right)))
def main(): bad([1],[2])
