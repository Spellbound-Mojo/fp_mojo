# error: invalid call to 'traverse_tap'
from fp.functions import pipeline
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Ok

def mismatch(left: List[Int], right: List[Int]):
    comptime Left = Span[Int, origin_of(left)]
    comptime Right = Span[Int, origin_of(right)]
    def observe(value: Int) -> Optional[Int]: return Optional(value)
    _ = pipeline[ResultFamily[Right]](Result[Int, Left](Ok(1))).traverse_tap[OptionalFamily](observe)
def main(): mismatch([1], [2])
