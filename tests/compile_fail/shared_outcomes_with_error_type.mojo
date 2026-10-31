# Canonical Result handlers may agree on a new stored-error type, but not on two.
# error: no matching method in call to 'redeem_with'
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def left(var value: Int) -> Result[Int, Int]: return Ok(value)
def right(var error: String) -> Result[Int, String]: return Ok(0)
def main(): _ = pipeline[ResultFamily[String]](Result[Int, String](Ok(1))).redeem_with(left, right)
