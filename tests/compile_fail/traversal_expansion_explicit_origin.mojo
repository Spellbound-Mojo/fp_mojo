# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok
def mismatch(left: List[Int], right: List[Int]):
    comptime Left = Span[Int, origin_of(left)]
    comptime Right = Span[Int, origin_of(right)]
    def wrong(value: Int) -> Optional[Result[Int, Right]]: return Optional(Result[Int, Right](Ok(value)))
    _ = piped(Result[Int, Left](Ok(1))).flat_traverse[OptionalFamily, ResultFamily[Left]](wrong)
def main(): mismatch([1], [2])
