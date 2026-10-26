# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.functions import pipeline
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Err
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    comptime Actual = type_of(view)
    comptime Expected = type_of(Span(anchor))
    def callback(value: Int) -> Optional[Bool]: return Optional(True)
    _ = pipeline[ResultFamily[Expected]](Result[Int,Actual](Err(view))).traverse_tap[OptionalFamily](callback).get()
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
