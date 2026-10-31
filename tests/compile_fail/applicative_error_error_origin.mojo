# The handler must consume the stored error with its exact origin.
# error: no matching method in call to 'or_else'
# error: cannot be converted
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def restore(var error: R) -> Result[Int, L]: return Ok(1)
    _ = pipeline[ResultFamily[L]](fail[ResultFamily[L], Int](Span(left))).or_else(restore).get()
def main(): bad([1], [2])
