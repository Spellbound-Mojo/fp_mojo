# error: no matching method in call to 'attempt_tap'
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def inspect(value: Result[R, String]) -> Result[Int, String]: return Ok(0)
    _ = pipeline[ResultFamily[String]](Result[L, String](Ok(Span(left)))).attempt_tap(inspect)
def main(): bad([1], [2])
