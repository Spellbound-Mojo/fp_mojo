# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, map, map2, map2_lazy, traverse, sequence
from fp.functions import pipeline
from fp.data import Result, Ok, Err

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime ActualView = type_of(actual)
    comptime ExpectedView = type_of(Span(anchor))
    comptime Actual = List[ActualView]
    comptime Expected = List[ExpectedView]
    comptime Family = ValidationFamily[ListMonoid[ExpectedView]]
    var source = List[Result[Int, Actual]]()
    source.append(Result[Int, Actual](Err(List[ActualView]([actual]))))
    _ = pipeline[ListFamily](source^).sequence[Family]().get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
