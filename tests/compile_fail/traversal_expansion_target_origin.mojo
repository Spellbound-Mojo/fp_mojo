# error: constraint
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok

def mismatch(left: List[Int], right: List[Int]):
    comptime Left = Span[Int, origin_of(left)]
    comptime Right = Span[Int, origin_of(right)]
    def wrong(value: Int) -> Result[Bool, Right]: return Ok(True)
    var xs: List[Int] = [1]
    _ = pipeline(xs^).filter_effect[ResultFamily[Left]](wrong)
def main(): mismatch([1], [2])
