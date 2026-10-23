# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def restore(var error: L) -> Result[Int, R]: return Ok(1)
    _ = piped(fail[ResultFamily[L], Int](Span(left))).or_else[ResultFamily[L]](restore).get()
def main(): bad([1], [2])
