# error: no matching
from fp.algebra import map, traverse, ListFamily, ResultFamily
from fp.data import Result, Ok
def inc(var x: Int) -> Int: return x+1
def main(): _ = map[ResultFamily[String]](Result[Int,Int](Ok(2)), inc)
