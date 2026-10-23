# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    comptime O = OptionalT[ResultFamily[L]]
    def restore(var error: L) -> Result[Optional[Int], R]: return Ok(Optional(1))
    _ = piped(fail[O, Int](Span(left))).or_else[O](restore).get()
def main(): bad([1], [2])
