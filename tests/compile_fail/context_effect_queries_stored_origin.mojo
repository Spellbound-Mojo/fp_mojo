# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Err
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    var failure = Span(right)
    def callback(value: Int) {failure} -> Result[Bool, Right]: return Err(failure)
    _ = pipeline(List[Int]([1])).find_effect[ResultFamily[Left]](callback).get()
def main(): check(List[Int]([1]), List[Int]([2]))
