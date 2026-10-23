# error: constraint
from fp.algebra import StringMonoid, ListMonoid, pure
from fp.effects import Reader, WriterT, LiftLocal, local
comptime R = Reader[Int]
comptime W = WriterT[R, StringMonoid]
def same(value: Int) -> Int: return value
def main(): _ = local[LiftLocal[W, R]](same, pure[WriterT[R, ListMonoid[Int]]](7))
