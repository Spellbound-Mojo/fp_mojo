# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, State, LiftListen, listen, tell
def main():
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    _ = listen[LiftListen[ReaderT[State[Int], Int], W]](R.lift(tell[W](String("a"))))
