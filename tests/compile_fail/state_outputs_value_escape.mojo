# error: cannot implicitly convert
from fp.effects import State, run_value
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([11])
    return run_value[State[Int]](State[Int].pure(Span(owner)),0)
def main(): _ = escape()
