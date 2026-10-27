from fp.algebra import FindContract, Monad, OptionalFamily
from fp.callables import BorrowCallable
from fp.iteration import find_effect
from std.testing import assert_equal

@fieldwise_init
struct Even(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke(self, ref value: Int) -> Self.Result:
        return Optional(value % 2 == 0)

def forward[I: Monad, V: Movable & Deinitable, C: BorrowCallable](
    var predicate: C, var source: V
) raises FindContract[I, V, C].Error -> FindContract[I, V, C].Out where FindContract[I, V, C].Compatible:
    return find_effect[I](predicate^, source^)

def main() raises:
    var result = forward[OptionalFamily](Even(), List[Int]([1, 2, 4]))
    assert_equal(result.value().value(), 2)
    print("retained match:", result.value().value())
