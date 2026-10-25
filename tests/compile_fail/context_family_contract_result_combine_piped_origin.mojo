# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, map, map2, map2_lazy, traverse, sequence
from fp.functions import pipeline, piped
from fp.callables import OnceBinary
from fp.data import Result, Ok, Err

@fieldwise_init
struct Combine(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var a: Int, var b: Int) -> Int: return a + b
def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime ActualView = type_of(actual)
    comptime ExpectedView = type_of(Span(anchor))
    comptime Actual = ActualView
    comptime Expected = ExpectedView
    comptime Family = ResultFamily[Expected]
    var left = Result[Int, Expected](Ok(1))
    var right = Result[Int, Actual](Err(actual))
    _ = piped(left^).map2[Family](right^, Combine()).get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
