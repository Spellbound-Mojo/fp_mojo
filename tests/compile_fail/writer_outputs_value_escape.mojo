# error: cannot implicitly convert
from fp.effects import Writer, run_value
from fp.algebra import StringMonoid
def select(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime W = Writer[StringMonoid]
    return run_value[W](W.pure(Span(owner)))
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([11])
    return select(owner)
def main(): _ = escape()
