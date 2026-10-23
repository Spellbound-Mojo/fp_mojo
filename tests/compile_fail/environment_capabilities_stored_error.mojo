# error: constraint
from fp.algebra import fail
from fp.effects import Reader, ResultT, LiftLocal, local
comptime R = Reader[Int]
comptime T = ResultT[R, String]
def same(value: Int) -> Int: return value
def main(): _ = local[LiftLocal[T, R]](same, fail[ResultT[R, Int], Int](7))
