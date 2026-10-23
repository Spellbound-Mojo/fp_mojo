# error: does not have witness table
from fp.iteration import iterated
from fp.algebra import OptionalFamily
from fp.data import Result, Ok
def project(value: Int) -> Result[Int, String]: return Ok(value)
def main(): _ = iterated(range(3)).traverse_void[OptionalFamily](project)
