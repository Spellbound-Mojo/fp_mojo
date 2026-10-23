# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
comptime A = WriterT[ResultFamily[String], StringMonoid]
comptime B = WriterT[ResultFamily[String], ListMonoid[String]]
def restore(var error: String) -> B.Pure[Int]: return pure[B](1)
def main():
    _ = piped(fail[A, Int](String("bad"))).or_else[A](restore).get()
