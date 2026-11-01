# error: cannot implicitly convert
from fp.effects import State, inspect, run
def fail[o: ImmOrigin](value: Span[Int,o]) raises Span[Int,o] -> Int: raise value
def project(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime E = Span[Int,origin_of(owner)]
    var pointer: def(E) raises E thin -> Int = fail[origin_of(owner)]
    try: _ = run[State[E]](inspect[State[E]](pointer),Span(owner))
    except error: return error
    return Span(owner)
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([71])
    return project(owner)
def main(): _ = escape()
