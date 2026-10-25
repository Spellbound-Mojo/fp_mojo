# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, map, map2, map2_lazy, traverse, sequence
from fp.functions import pipeline, piped
from fp.data import Result, Ok, Err

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime ActualView = type_of(actual)
    comptime ExpectedView = type_of(Span(anchor))
    comptime Actual = ActualView
    comptime Expected = ExpectedView
    comptime Family = ResultFamily[Expected]
    var source = Result[Int, Actual](Err(actual))
    def inc(var value: Int) -> Int: return value + 1
    _ = pipeline[Family](source^).map(inc).get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
