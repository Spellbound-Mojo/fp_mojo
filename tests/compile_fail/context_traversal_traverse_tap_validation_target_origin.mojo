# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.functions import pipeline
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result, Err
def check(anchor: List[Int], local: List[Int]):
    var local_view = Span(local)
    comptime Actual = type_of(local_view)
    comptime Expected = type_of(Span(anchor))
    def callback(value: Int) {local_view} -> Result[Bool,List[Actual]]: return Err(List[Actual]([local_view]))
    _ = pipeline(List[Int]([1])).traverse_tap[ValidationFamily[ListMonoid[Expected]]](callback).get()
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
