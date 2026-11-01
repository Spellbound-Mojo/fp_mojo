# error: no matching method in call to 'attempt_tap'
from fp.data import Result, Ok, Err
def inspect(value: Result[Int, String]) -> Result[Int, Int]: return Err(1)
def main(): _ = Result[Int, String](Ok(1)).attempt_tap(inspect)
