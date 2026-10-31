# error: constraint
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok
def mismatch(left: List[Int],right: List[Int]):
    comptime L = Span[Int,origin_of(left)]
    comptime R = Span[Int,origin_of(right)]
    def wrong(a: Int,b: Int) -> Result[Int,R]: return Ok(a+b)
    var xs: List[Int] = [1]
    _ = pipeline(xs^).fold_effect[ResultFamily[L]](0).run(wrong)
def main(): mismatch([1],[2])
