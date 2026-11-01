# error: cannot implicitly convert
from fp.algebra import Monoid
from fp.effects import Writer, writer
from fp.functions import pipeline
struct Log[o: ImmOrigin](Monoid):
    comptime Value = Optional[Span[Int,Self.o]]
    @staticmethod
    def empty() -> Self.Value: return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value: return right^
def appended(ref owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime W = Writer[Log[origin_of(owner)]]
    var result = pipeline(writer[W,Int]((Optional[Span[Int,origin_of(owner)]](),7))).tell(Optional(Span(owner))).run()
    return result[0].value()
def bad() -> Span[Int,ImmUntrackedOrigin]:
    var local = List[Int]([1])
    return appended(local)
def main():
    _ = bad()
