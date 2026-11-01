# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import ListMonoid
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    _ = pipeline(List[Result[Int,List[R]]]([Result[Int,List[R]](Ok(1))])).par_sequence[ListMonoid[L]]().get()
def main(): check(List[Int]([1]),List[Int]([2]))
