# error: invalid call to 'map_err': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Err

def reject(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    def replace(var error: Left) {ref right} -> Right: return Span(right)
    _ = pipeline(Result[Int,Left](Err(Span(left)))).map_err[Target=ResultFamily[Left]](replace)

def main():
    reject(List[Int]([1]),List[Int]([2]))
