# error: lacking evidence
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    _ = pipeline[ResultFamily[L]](Result[Int,R](Ok(1))).void().get()
def main(): check(List[Int]([1]),List[Int]([2]))
