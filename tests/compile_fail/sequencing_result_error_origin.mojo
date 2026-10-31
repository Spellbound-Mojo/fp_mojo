# error: constraint
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int,origin_of(left)]
    comptime R = Span[Int,origin_of(right)]
    def check(value: Int) -> Result[Int,R]: return Ok(value)
    _ = pipeline(Result[Int,L](Ok(1))).flat_tap(check).get()
def main(): bad([1],[2])
