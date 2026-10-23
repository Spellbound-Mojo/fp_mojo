# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def left(var value: Int) -> Result[Int, Int]: return Ok(value)
def right(var error: String) -> Result[Int, Int]: return Ok(0)
def main(): _ = piped(Result[Int, String](Ok(1))).redeem_with[ResultFamily[String]](left, right)
