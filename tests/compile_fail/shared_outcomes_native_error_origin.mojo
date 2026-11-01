# error: constraint
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def success(var value: Int) raises L -> Int: return value
    def failure(var error: String) raises R -> Int: return 0
    try:
        _ = pipeline[ResultFamily[String]](Result[Int, String](Ok(1))).redeem(success, failure)
    except error: pass
def main(): bad([1], [2])
