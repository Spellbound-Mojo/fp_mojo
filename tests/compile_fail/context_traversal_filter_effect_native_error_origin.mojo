# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    comptime Actual = type_of(view)
    comptime Expected = type_of(Span(anchor))
    def callback(value: Int) raises Actual {view} -> Optional[Bool]: raise view
    try: _ = pipeline(List[Int]([1])).raising[Expected]().filter_effect[OptionalFamily](callback).get()
    except _: pass
def main():
    var anchor = List[Int]([1])
    var local = List[Int]([2])
    check(anchor,local)
