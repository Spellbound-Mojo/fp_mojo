# error: lacking evidence
from fp.functions import pipeline
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    _ = pipeline(Result[Int,List[L]](Ok(1))).par_product_n((Result[Int,List[R]](Ok(2)),)).get()
def main(): check(List[Int]([1]),List[Int]([2]))
