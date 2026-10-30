from fp.algebra import IfContract, Monad, OptionalFamily, if_effect
from fp.callables import ThunkContract, Thunk
from std.testing import assert_equal

@fieldwise_init
struct Value(Thunk):
    var number: Int
    comptime Out = Optional[Int]
    def call(self) -> Self.Out:
        return Optional(self.number)

def choose[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    var on_true: L, var on_false: R, var condition: V
) raises IfContract[I, V, L, R].Error -> IfContract[I, V, L, R].Out where IfContract[I, V, L, R].Compatible:
    return if_effect[I](condition^, on_true^, on_false^)

def main() raises:
    var selected = choose[OptionalFamily](Value(14), Value(21), Optional(True))
    assert_equal(selected.value(), 14)
    print("selected:", selected.value())
