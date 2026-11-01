# error: constraint
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def bad(left:List[Int],right:List[Int]):
    comptime L = Span[Int,origin_of(left)]
    comptime R = Span[Int,origin_of(right)]
    def source(x:Int) -> Result[Int,L]: return Ok(x)
    def other(x:Int) -> Result[Int,R]: return Ok(x)
    _ = kleisli[ResultFamily[L]](source).then(other).call_once(1)
def main(): bad([1],[2])
