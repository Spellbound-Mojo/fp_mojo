# error: constraint
from fp.functions import piped
from fp.data import Result, Ok
from fp.callables import as_unary
def increment(x: Int) -> Int: return x+1
def mismatch(left: List[Int],right: List[Int]):
    var function = as_unary(increment)
    var source = Result[type_of(function),Span[Int,origin_of(left)]](Ok(function^))
    var values = Result[Int,Span[Int,origin_of(right)]](Ok(1))
    _ = piped(source^).ap(values^).get()
def main(): mismatch([1],[2])
