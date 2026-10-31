# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, map, map2, map2_lazy, traverse, sequence
from fp.functions import pipeline
from fp.callables import OnceBinary, OnceThunk
from fp.data import Result, Ok, Err

@fieldwise_init
struct Combine(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var a: Int, var b: Int) -> Int: return a + b
@fieldwise_init
struct Deferred[E: Movable & Deinitable](OnceThunk):
    var value: Result[Int, Self.E]
    comptime Out = Result[Int, Self.E]
    def call_once(deinit self) -> Self.Out: return self.value^

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime ActualView = type_of(actual)
    comptime ExpectedView = type_of(Span(anchor))
    comptime Actual = List[ActualView]
    comptime Expected = List[ExpectedView]
    comptime Family = ValidationFamily[ListMonoid[ExpectedView]]
    var left = Result[Int, Expected](Ok(1))
    var right = Result[Int, Actual](Err(List[ActualView]([actual])))
    _ = map2_lazy[Family](left^, Deferred(right^), Combine())
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
