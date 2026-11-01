# error: cannot implicitly convert
from fp.functions import pipeline
from fp.effects import Writer, writer
from fp.algebra import ListMonoid
def select(owner: List[Int]) -> List[Span[Int,origin_of(owner)]]:
    comptime L = Span[Int,origin_of(owner)]
    comptime W = Writer[ListMonoid[L]]
    return pipeline(writer[W,Int]((List[L]([Span(owner)]),7))).run_log()
def escape() -> List[Span[Int,ImmUntrackedOrigin]]:
    var owner = List[Int]([23])
    return select(owner)
def main(): _ = escape()
