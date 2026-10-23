# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def inspect(value: Result[Int, String]) -> Result[Int, Int]: return Ok(0)
def main(): _ = piped(Result[Int, String](Ok(1))).attempt_tap[ResultFamily[String]](inspect)
