# error: constraint
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    var view = Span(right)
    def good(var value: Int) -> Result[Int, L]: return Ok(value)
    def wrong(var error: L) {view} -> Result[Int, type_of(view)]: return Err(view)
    _ = piped(Result[Int, L](Ok(1))).redeem_with[ResultFamily[L]](good, wrong)
def main(): bad([1], [2])
