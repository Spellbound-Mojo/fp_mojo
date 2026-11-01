# error: constraint
from fp.effects import Reader, ReaderT, StateT, LiftLocal, ask, local
from fp.algebra import flat_map
from fp.callables import as_unary
comptime R = Reader[Int]
comptime RR = ReaderT[R, Int]
comptime S = StateT[RR, Int]
comptime C = LiftLocal[S, RR]
def next_value(var value: Int) -> RR.Asked: return ask[RR]()
def change(value: Int) -> Int: return value + 1
def main():
    _ = local[C](S.lift(flat_map[RR](ask[RR](), as_unary(next_value))), change)
