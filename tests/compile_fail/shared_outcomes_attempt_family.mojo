# error: no matching method
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import piped
from fp.data import Result, Ok
def inspect(value: Result[Int, List[String]]) -> Result[Int, List[String]]: return Ok(0)
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = piped(fail[V, Int](List[String](["bad"]))).attempt_tap[V](inspect)
