# error: cannot implicitly convert
from fp.effects import Writer, writer, run
from fp.algebra import StringMonoid
def unwrap(owner: List[Int]) -> Tuple[String,Span[Int,origin_of(owner)]]:
    comptime V = Span[Int,origin_of(owner)]
    comptime W = Writer[StringMonoid]
    return run[W](writer[W,V]((String("log"),Span(owner))))
def escape() -> Tuple[String,Span[Int,ImmUntrackedOrigin]]:
    var owner = List[Int]([11])
    return unwrap(owner)
def main(): _ = escape()
