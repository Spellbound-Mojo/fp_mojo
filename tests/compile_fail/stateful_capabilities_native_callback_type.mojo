# error: constraint
from fp.effects import State, ReaderT, LiftStateful, modify
def wrong(var value: Int) -> String: return String(value)
def main():
    comptime S = State[Int]
    _ = modify[LiftStateful[ReaderT[S, Int], S]](wrong)
