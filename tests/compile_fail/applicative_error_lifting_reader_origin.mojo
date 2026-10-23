# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime I = ReaderT[ResultFamily[String], Int]
    var view = Span(right)
    def restore(var error: String) {view} -> type_of(view): return view
    _ = piped(fail[I, L](String("bad"))).recover[I](restore).get()
def main(): bad([1], [2])
