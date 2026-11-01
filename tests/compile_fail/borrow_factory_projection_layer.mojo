# error: no matching
from fp.effects import Reader, State, OptionalT, LiftProject, asks
def read(value: Int) -> Int: return value
def main():
    var pointer: def(Int) thin -> Int = read
    _ = asks[LiftProject[OptionalT[Reader[Int]],State[Int]]](pointer)
