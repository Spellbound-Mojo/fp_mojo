# error: constraint
from fp.data import Result, Ok
def mismatch(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    comptime B = type_of(b)
    def wrong() {b} -> B: return b
    _ = Result[type_of(a), Int](Ok(a)).get_or_else(wrong)
def main(): mismatch([1], [2])
