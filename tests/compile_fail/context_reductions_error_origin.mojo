# error: no matching method
from fp.functions import pipeline
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    var view=Span(right)
    def bad(var value:Int) raises R {view} -> Int: raise view
    _ = pipeline(range(3)).raising[L]().sum_by(bad).get()
def main(): check(List[Int]([1]),List[Int]([2]))
