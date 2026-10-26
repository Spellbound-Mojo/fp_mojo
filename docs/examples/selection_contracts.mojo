"""One contract per generic selection or lazy combination."""
from fp.algebra import Filterable, Applicative, FilterContract, CombineContract, ListFamily, OptionalFamily
from fp.algebra import filter, map2_lazy
from fp.callables import BorrowCallable, BinaryContract, ThunkContract, Binary, OnceThunk
from std.testing import assert_equal

def select[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var values: V, var predicate: P) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
    return filter[I](predicate^, values^)

def combine[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: V, var right: R, var function: F) raises CombineContract[I, V, F, R].Error -> CombineContract[I, V, F, R].Out where CombineContract[I, V, F, R].Compatible:
    return map2_lazy[I](function^, left^, right^)

@fieldwise_init
struct Positive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref value: Int) -> Bool: return value > 0

@fieldwise_init
struct Add(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var left: Int, var right: Int) -> Int: return left + right

@fieldwise_init
struct Later(OnceThunk):
    var value: Int
    comptime Out = Optional[Int]
    def call_once(deinit self) -> Self.Out: return Optional(self.value)

def main() raises:
    var kept = select[ListFamily](List[Int]([-1, 3, 7]), Positive())
    assert_equal(kept, [3, 7])
    var sum = combine[OptionalFamily](Optional(3), Later(7), Add())
    assert_equal(sum.value(), 10)
    print("selected:", kept[0], kept[1])
    print("combined:", sum.value())
