# error: constraint
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def inspect(value: Result[Int, L]) -> Result[Int, R]: return Ok(0)
    _ = piped(Result[Int, L](Ok(1))).attempt_tap[ResultFamily[L]](inspect)
def main(): bad([1], [2])
