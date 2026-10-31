# error: constraint
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def success(var value: L) -> Result[L, R]: return Ok(value)
    def failure(var value: R) -> Result[R, R]: return Ok(value)
    _ = pipeline[ResultFamily[R]](Result[L, R](Ok(Span(left)))).redeem_with(success, failure)
def main(): bad([1], [2])
