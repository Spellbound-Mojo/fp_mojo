# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    var view = Span(right)
    def restore(var error: String) {view} -> type_of(view): return view
    _ = pipeline[ResultFamily[String]](fail[ResultFamily[String], L](String("bad"))).recover(restore).get()
def main(): bad([1], [2])
