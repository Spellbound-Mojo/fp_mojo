# error: lacking evidence to prove correctness
# error: origin_of(anchor)
# error: origin_of(local)
from fp.algebra import map2, ResultFamily, ValidationFamily, StringMonoid
from fp.callables import OnceBinary
from fp.data import Result, Ok
@fieldwise_init
struct Combine[View: Movable & Deinitable](OnceBinary):
    comptime First = Int
    comptime Second = Self.View
    comptime Out = Int
    def call_once(deinit self, var a: Self.First, var b: Self.Second) -> Int: return 1

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    comptime Actual = type_of(actual)
    comptime Expected = type_of(Span(anchor))
    _ = map2[ResultFamily[String]](Combine[Expected](), Result[Int,String](Ok(1)), Result[Actual,String](Ok(actual)))
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor,local)
