# error: no matching method in call to 'attempt_tap'
# error: value passed to 'function' cannot be converted from 'def inspect(var value
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def inspect(var value: Result[Int, String]) -> Result[Int, String]: return value^
def main(): _ = pipeline[ResultFamily[String]](Result[Int, String](Ok(1))).attempt_tap(inspect)
