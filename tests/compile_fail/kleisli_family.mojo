# error: matching
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x:Int) -> Result[Int,String]: return Ok(x)
def other(x:Int) -> Optional[Int]: return Optional(x)
def main():
    _ = kleisli[ResultFamily[String]](source).then(kleisli[OptionalFamily](other))
