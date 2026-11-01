# error: cannot implicitly convert
from fp.effects import IO, Outcome, scoped_io, lift_resource, pure_resource, run_io
def fail[o: ImmOrigin](value: Span[Int,o]) raises Span[Int,o] -> IO[Span[Int,o]].Pure[Int]:
    raise value
def run(owner: List[Int]) -> Outcome[Int,Span[Int,origin_of(owner)]]:
    comptime E = Span[Int,origin_of(owner)]
    var pointer: def(E) raises E thin -> IO[E].Pure[Int] = fail[origin_of(owner)]
    return run_io(lift_resource(pure_resource[E](Span(owner))).use(scoped_io(pointer)))
def escape() -> Outcome[Int,Span[Int,ImmUntrackedOrigin]]:
    var owner = List[Int]([71])
    return run(owner)
def main(): _ = escape()
