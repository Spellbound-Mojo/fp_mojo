# error: Result retention: callback must return a Result with the same error type
from fp.data import Result, Ok
def project(value: Int) -> Result[Int, Int]: return Ok(value)
def main():
    _ = Result[Int, String](Ok(1)).flat_pair_with(project)
