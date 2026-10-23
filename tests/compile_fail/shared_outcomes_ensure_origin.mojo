# error: constraint
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    var view = Span(right)
    def predicate(value: Int) -> Bool: return False
    def factory(value: Int) {view} -> type_of(view): return view
    _ = piped(Result[Int, L](Ok(1))).ensure[ResultFamily[L]](predicate, factory)
def main(): bad([1], [2])
