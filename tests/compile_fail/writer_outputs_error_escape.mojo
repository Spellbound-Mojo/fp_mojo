# error: cannot implicitly convert
from fp.functions import pipeline
from fp.effects import WriterT, Reader, writer, run_log, asks
from fp.algebra import StringMonoid
def fail[o: ImmOrigin](value: Span[Int,o]) raises Span[Int,o] -> Tuple[String,Int]: raise value
def observe(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime E = Span[Int,origin_of(owner)]
    comptime R = Reader[E]
    comptime W = WriterT[R,StringMonoid]
    var pointer: def(E) raises E thin -> Tuple[String,Int] = fail[origin_of(owner)]
    var pending = run_log[W](writer[W,Int](asks[R](pointer)))
    var view = Span(owner)
    try: _ = pipeline(pending^).run(view)
    except error: return error
    return Span(owner)
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([71])
    return observe(owner)
def main(): _ = escape()
