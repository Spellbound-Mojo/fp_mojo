# error: constraint
from fp.algebra import OptionalFamily
from fp.effects import Reader, ReaderT, ask, local
def same(value: Int) -> Int: return value
def main(): _ = local[ReaderT[OptionalFamily, Int]](same, ask[Reader[Int]]())
