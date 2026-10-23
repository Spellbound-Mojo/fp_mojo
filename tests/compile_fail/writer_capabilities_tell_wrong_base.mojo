# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, State, LiftTell, tell
def main():
    _ = tell[LiftTell[ReaderT[State[Int], Int], Writer[StringMonoid]]](String("a"))
