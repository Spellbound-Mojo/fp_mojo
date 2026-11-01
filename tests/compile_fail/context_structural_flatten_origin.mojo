# error: lacking evidence
from fp.functions import pipeline
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    var source=Result[Result[Int,L],R](Ok(Result[Int,L](Ok(1))))
    _ = pipeline(source^).flatten().get()
def main(): check(List[Int]([1]),List[Int]([2]))
