from fp.algebra import AnyContract, AllContract, Monad, OptionalFamily
from fp.callables import BorrowCallable
from fp.iteration import any_effect, all_effect
from std.testing import assert_equal

@fieldwise_init
struct Even(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke(self, ref value: Int) -> Self.Result:
        return Optional(value % 2 == 0)

def some[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AnyContract[I, V, C].Error -> AnyContract[I, V, C].Out where AnyContract[I, V, C].Compatible:
    return any_effect[I](predicate^, source^)

def every[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AllContract[I, V, C].Error -> AllContract[I, V, C].Out where AllContract[I, V, C].Compatible:
    return all_effect[I](predicate^, source^)

def main() raises:
    var found = some[OptionalFamily](Even(), List[Int]([1, 2, 4]))
    var complete = every[OptionalFamily](Even(), List[Int]([1, 2, 4]))
    assert_equal(found.value(), True)
    assert_equal(complete.value(), False)
    print("any:", found.value())
    print("all:", complete.value())
