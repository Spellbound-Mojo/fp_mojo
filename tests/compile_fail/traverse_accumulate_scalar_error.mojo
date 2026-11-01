# error: no matching function in call to 'traverse'
from fp.iteration import traverse
from fp.algebra import Accumulate
from fp.data import Result, Ok
def check(var value: Int) -> Result[Int, String]: return Ok(value)
def main() raises:
    _ = traverse[Accumulate](List[Int]([1]), check)
