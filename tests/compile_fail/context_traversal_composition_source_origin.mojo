# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Err
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    var source = Result[Optional[Int],Right](Err(Span(right)))
    _ = pipeline[ResultFamily[Left]](source^).sequence_void[OptionalFamily]().get()
def main(): check(List[Int]([1]), List[Int]([2]))
