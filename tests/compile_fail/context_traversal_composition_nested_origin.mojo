# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.data import Result, Ok, Err
def check(left: List[Int], right: List[Int]):
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    var failure = Span(right)
    def callback(var value: Int) {failure} -> Optional[Result[Int,Right]]: return Optional(Result[Int,Right](Err(failure)))
    _ = pipeline(Result[Int,Left](Ok(1))).flat_traverse[OptionalFamily](callback).get()
def main(): check(List[Int]([1]), List[Int]([2]))
