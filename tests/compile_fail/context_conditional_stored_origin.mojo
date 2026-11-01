# error: lacking evidence
from fp.functions import pipeline
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    def first()->Result[Int,L]: return Ok(1)
    def second()->Result[Int,R]: return Ok(2)
    _ = pipeline(Result[Bool,L](Ok(True))).if_effect(first,second).get()
def main(): check(List[Int]([1]),List[Int]([2]))
