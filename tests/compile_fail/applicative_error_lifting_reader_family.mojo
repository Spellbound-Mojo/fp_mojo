# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import pipeline
from fp.data import Result, Ok
comptime A = ReaderT[ResultFamily[String], Int]
comptime B = ReaderT[ResultFamily[Int], Int]
def restore(var error: String) -> B.Pure[Int]: return pure[B](1)
def main():
    _ = pipeline[A](fail[A, Int](String("bad"))).or_else(restore).get()
