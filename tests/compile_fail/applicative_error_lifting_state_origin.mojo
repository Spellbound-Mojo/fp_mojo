# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime A = StateT[ResultFamily[String], Span[Int, origin_of(left)]]
    comptime B = StateT[ResultFamily[String], Span[Int, origin_of(right)]]
    def restore(var error: String) -> B.Pure[Int]: return pure[B](1)
    _ = pipeline[A](fail[A, Int](String("bad"))).or_else(restore).get()
def main(): bad([1], [2])
