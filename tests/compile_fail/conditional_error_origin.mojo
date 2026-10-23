# error: constraint
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime I = ReaderT[ResultFamily[String], Int]
    var view = Span(right)
    def predicate(error: String) -> Bool: return True
    def restore(var error: String) {view} -> type_of(view): return view
    _ = piped(fail[I, L](String("bad"))).recover_if[I](predicate, restore).get()
def main(): bad([1], [2])
