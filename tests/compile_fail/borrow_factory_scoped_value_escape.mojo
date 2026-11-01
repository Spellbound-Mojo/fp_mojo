# error: cannot implicitly convert
from fp.effects import IO, Outcome, scoped_io, lift_resource, pure_resource, run_io
def keep[o: ImmOrigin](value: Span[Int,o]) -> IO[Int].Pure[Span[Int,o]]:
    return IO[Int].pure(value)
def run(owner: List[Int]) -> Outcome[Span[Int,origin_of(owner)],Int]:
    comptime V = Span[Int,origin_of(owner)]
    var pointer: def(V) thin -> IO[Int].Pure[V] = keep[origin_of(owner)]
    return run_io(lift_resource(pure_resource[Int](Span(owner))).use(scoped_io(pointer)))
def escape() -> Outcome[Span[Int,ImmUntrackedOrigin],Int]:
    var owner = List[Int]([11])
    return run(owner)
def main(): _ = escape()
