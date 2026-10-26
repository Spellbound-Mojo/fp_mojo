# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result, Err
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime Actual = type_of(actual)
    comptime Expected = type_of(Span(anchor))
    def callback(value: Int) -> Int: return value
    _ = pipeline[ResultFamily[Expected]](Result[Int,Actual](Err(actual))).pair_with(callback).get()
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
