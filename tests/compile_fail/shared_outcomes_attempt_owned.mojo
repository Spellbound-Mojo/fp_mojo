# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def inspect(var value: Result[Int, String]) -> Result[Int, String]: return value^
def main(): _ = piped(Result[Int, String](Ok(1))).attempt_tap[ResultFamily[String]](inspect)
