# error: constraint
from fp.algebra import ListMonoid
from fp.data import Result, Ok
from fp.iteration import iterated

def bad(left: List[Int], right: List[Int]):
    comptime R = Result[Int,List[Span[Int,origin_of(right)]]]
    var values: List[R] = [R(Ok(1))]
    _ = iterated(values^).par_sequence[ListMonoid[Span[Int,origin_of(left)]]]()
def main(): bad([1],[2])
