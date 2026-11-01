# error: constraint
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x:Int) -> Result[Int,String]: return Ok(x)
def other(x:Int) -> Result[Int,Int]: return Ok(x)
def main():
    _ = kleisli[ResultFamily[String]](source).then(other).call_once(1)
