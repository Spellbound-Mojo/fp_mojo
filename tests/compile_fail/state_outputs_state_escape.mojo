# error: cannot implicitly convert
from fp.functions import pipeline
from fp.effects import State
def select(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    comptime I = State[Span[Int,origin_of(owner)]]
    return pipeline(I.pure(7)).run_state(Span(owner))
def escape() -> Span[Int,ImmUntrackedOrigin]:
    var owner = List[Int]([11])
    return select(owner)
def main(): _ = escape()
