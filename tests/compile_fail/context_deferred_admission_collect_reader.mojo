# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, State, Writer, OptionalT, ResultT
from fp.algebra import StringMonoid, ListMonoid
from fp.data import Result, Ok
def next(var x: Int) -> Reader[String].Pure[Int]: return Reader[String].pure(x)
def main():
    _ = pipeline(List[Int]([1])).traverse[Reader[Int]](next).get()
