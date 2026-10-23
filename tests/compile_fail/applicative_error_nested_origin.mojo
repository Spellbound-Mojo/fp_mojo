# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.effects import ResultT
from fp.data import Result, Ok, Err
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def restore(var error: L) -> List[Result[Int, R]]: return List[Result[Int, R]]([Result[Int, R](Ok(1))])
    _ = piped(fail[ResultT[ListFamily, L], Int](Span(left))).or_else[ResultT[ListFamily, L]](restore).get()
def main(): bad([1], [2])
