# error: no matching method
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import pipeline
from fp.data import Result, Ok
def left(var value: Int) -> Result[Int, List[String]]: return Ok(value)
def right(var error: List[String]) -> Result[Int, List[String]]: return Ok(0)
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = pipeline(fail[V, Int](List[String](["bad"]))).redeem_with[I=V](left, right)
