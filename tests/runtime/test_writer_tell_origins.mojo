"""Log and payload borrows retain independent caller origins."""
from fp.algebra import Monoid
from fp.effects import WriterT, Reader, writer, TellContract
from fp.functions import pipeline
from std.testing import assert_equal


struct Views[o: ImmOrigin](Monoid):
    comptime Value = Optional[Span[Int,Self.o]]
    @staticmethod
    def empty() -> Self.Value: return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        if right: return right^
        return left^


def borrowed(log: List[Int], payload: List[Int]) raises:
    comptime L = Span[Int,origin_of(log)]
    comptime P = Span[Int,origin_of(payload)]
    comptime R = Reader[Int]
    comptime W = WriterT[R,Views[origin_of(log)]]
    var value = writer[W,P](R.pure((Optional[L](),Span(payload))))
    var pending = pipeline(value^).tell(Optional(Span(log))).run()
    var result = pipeline(pending^).run(0)
    comptime assert type_of(result) == Tuple[Optional[L],P]
    assert_equal(result[0].value()[0],11)
    assert_equal(result[1][0],22)


def main() raises:
    borrowed([11],[22])
