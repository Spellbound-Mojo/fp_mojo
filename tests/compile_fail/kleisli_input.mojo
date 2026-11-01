# error: constraint
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x: Int) -> Result[Int,String]: return Ok(x)
def wrong(x: String) -> Result[Int,String]: return Ok(1)
def main():
    _ = kleisli[ResultFamily[String]](source).then(wrong).call_once(1)
