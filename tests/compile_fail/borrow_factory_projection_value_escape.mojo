# error: cannot implicitly convert
from fp.effects import Reader, asks, run
def read[o: ImmOrigin](value: Span[Int,o]) -> Span[Int,o]: return value
def project(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime V = Span[Int,origin_of(owner)]
    var pointer: def(V) thin -> V = read[origin_of(owner)]
    var view = Span(owner)
    return run[Reader[V]](asks[Reader[V]](pointer),view)
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([11])
    return project(owner)
def main(): _ = escape()
