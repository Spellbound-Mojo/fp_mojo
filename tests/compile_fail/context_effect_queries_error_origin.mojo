# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.data import Result, Err
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    var failure = Span(right)
    def callback(value: Int) raises Right {failure} -> Optional[Bool]: raise failure
    _ = pipeline(List[Int]([1])).raising[Left]().find_effect[OptionalFamily](callback).get()
def main(): check(List[Int]([1]), List[Int]([2]))
