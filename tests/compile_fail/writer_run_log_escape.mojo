# error: cannot implicitly convert
from fp.effects import Writer, writer, run
from fp.algebra import ListMonoid
def unwrap(owner: List[Int]) -> Tuple[List[Span[Int,origin_of(owner)]],Int]:
    comptime L = Span[Int,origin_of(owner)]
    comptime W = Writer[ListMonoid[L]]
    return run[W](writer[W,Int]((List[L]([Span(owner)]),7)))
def escape() -> Tuple[List[Span[Int,ImmUntrackedOrigin]],Int]:
    var owner = List[Int]([23])
    return unwrap(owner)
def main(): _ = escape()
