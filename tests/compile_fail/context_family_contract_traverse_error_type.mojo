# error: no matching
from fp.algebra import map, traverse, ListFamily, ResultFamily
from fp.data import Result, Ok
def next(var x: Int) -> Result[Int,Int]: return Ok(x)
def main(): _ = traverse[ListFamily,ResultFamily[String]](List[Int]([1]), next)
