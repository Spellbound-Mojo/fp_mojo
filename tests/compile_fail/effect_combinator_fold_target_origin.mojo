# error: constraint
from fp.functions import piped
from fp.algebra import ResultFamily
from fp.data import Result, Ok
def mismatch(left: List[Int],right: List[Int]):
    comptime L = Span[Int,origin_of(left)]
    comptime R = Span[Int,origin_of(right)]
    def wrong(a: Int,b: Int) -> Result[Int,R]: return Ok(a+b)
    var xs: List[Int] = [1]
    _ = piped(xs^).fold_effect[ResultFamily[L]](wrong,0)
def main(): mismatch([1],[2])
