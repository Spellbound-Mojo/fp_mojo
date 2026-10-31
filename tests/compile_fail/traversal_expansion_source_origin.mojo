# error: constraint
from fp.functions import piped
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Ok

def mismatch(left: List[Int], right: List[Int]):
    comptime Left = Span[Int, origin_of(left)]
    comptime Right = Span[Int, origin_of(right)]
    def observe(value: Int) -> Optional[Int]: return Optional(value)
    _ = piped(Result[Int, Left](Ok(1))).traverse_tap[OptionalFamily, ResultFamily[Right]](observe)
def main(): mismatch([1], [2])
