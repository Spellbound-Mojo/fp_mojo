# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, State, Writer, OptionalT, ResultT
from fp.algebra import StringMonoid, ListMonoid
from fp.data import Result, Ok
def inc(var x: Int) -> Int: return x + 1
def main():
    _ = pipeline[OptionalT[Reader[Int]]](Reader[Int].pure(List[Int]([1]))).map(inc).get()
