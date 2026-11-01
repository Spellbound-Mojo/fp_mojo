# error: constraint
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def predicate(error: R) -> Bool: return True
    def restore(var error: L) -> Int: return 0
    _ = pipeline[ResultFamily[L]](fail[ResultFamily[L], Int](Span(left))).recover_if(predicate, restore).get()
def main(): bad([1], [2])
