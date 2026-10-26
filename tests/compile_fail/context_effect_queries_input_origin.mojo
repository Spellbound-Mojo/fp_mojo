# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    def callback(value: Left) -> Optional[Bool]: return Optional(True)
    _ = pipeline(List[Right]([Span(right)])).find_effect[OptionalFamily](callback).get()
def main(): check(List[Int]([1]), List[Int]([2]))
