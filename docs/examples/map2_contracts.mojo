from fp.algebra import Applicative, OptionalFamily, map2
from fp.algebra.contracts import Map2Contract
from fp.callables import BinaryContract, Binary
from std.testing import assert_equal

@fieldwise_init
struct Add(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int:
        return first + second

def combine[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var left: V, var right: W
) raises Map2Contract[I, V, W, F].Error -> Map2Contract[I, V, W, F].Out where Map2Contract[I, V, W, F].Compatible:
    return map2[I](function^, left^, right^)

def main() raises:
    var result = combine[OptionalFamily](Add(), Optional(3), Optional(4))
    assert_equal(result.value(), 7)
    print("combined:", result.value())
