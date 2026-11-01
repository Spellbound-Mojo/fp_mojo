# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def inspect(value: Result[Int, String]) -> Result[Int, Int]: return Ok(0)
def main(): _ = pipeline(Result[Int, String](Ok(1))).attempt_tap[ResultFamily[String]](inspect)
