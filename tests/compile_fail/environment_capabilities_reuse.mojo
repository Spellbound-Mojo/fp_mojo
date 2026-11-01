# error: use of uninitialized value
from fp.effects import Reader, StateT, LiftLocal, ask, local, run
def same(value: Int) -> Int: return value
def main():
    comptime R = Reader[Int]
    comptime S = StateT[R, Int]
    comptime C = LiftLocal[S, R]
    var scoped = local[C](ask[C](), same)
    _ = run[S](scoped^, 0)
    _ = run[S](scoped^, 0)
