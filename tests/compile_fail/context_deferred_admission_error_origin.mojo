# error: invalid call to 'map': lacking evidence to prove correctness
from fp.effects import Reader, ResultT
from fp.functions import pipeline
from fp.data import Result, Err

def increment(var value: Int) -> Int: return value + 1

def check(left: List[Int], right: List[Int]):
    var expected = Span(left)
    var other = Span(right)
    comptime I = ResultT[Reader[Int], type_of(expected)]
    var source = Reader[Int].pure(Result[Int, type_of(other)](Err(other)))
    _ = pipeline[I](source^).map(increment).get()

def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    check(left, right)
