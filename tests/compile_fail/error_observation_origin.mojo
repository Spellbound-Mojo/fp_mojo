# error: constraint
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def inspect(error: R) -> Int: return 0
    _ = piped(fail[ResultFamily[L], Int](Span(left))).tap_err[ResultFamily[L]](inspect).get()
def main(): bad([1], [2])
