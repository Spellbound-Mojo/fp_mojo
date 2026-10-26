# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, State, Writer, OptionalT, ResultT
from fp.algebra import StringMonoid, ListMonoid
from fp.data import Result, Ok
def next(var x: Int) -> Int: return x
def main():
    _ = pipeline[Reader[Int]](Reader[Int].pure(1)).flat_map(next).get()
