# error: no matching
from fp.effects import Reader, State, OptionalT, LiftProject, asks
def keep(value: Int) -> Int: return value
def main(): _ = asks[LiftProject[OptionalT[Reader[Int]], State[Int]]](keep)
