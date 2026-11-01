# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    def combine(var value:Int,var view:L)->Int: return value+len(view)
    _ = pipeline(Result[Int,List[String]](Ok(1))).par_map_n((Result[R,List[String]](Ok(Span(right))),),combine).get()
def main(): check(List[Int]([1]),List[Int]([2]))
