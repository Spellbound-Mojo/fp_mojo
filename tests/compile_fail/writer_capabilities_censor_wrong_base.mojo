# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, State, LiftCensor, censor, tell
def same(var log: String) -> String: return log^
def main():
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    _ = censor[LiftCensor[ReaderT[State[Int], Int], W]](R.lift(tell[W](String("a"))), same)
