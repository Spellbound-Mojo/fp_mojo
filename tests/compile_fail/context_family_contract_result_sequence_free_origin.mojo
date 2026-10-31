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
    var source = List[Result[Int, Actual]]()
    source.append(Result[Int, Actual](Err(actual)))
    _ = sequence[Family, ListFamily](source^)
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
