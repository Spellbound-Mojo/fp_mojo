from fp.algebra import FindMapContract, Monad, OptionalFamily
from fp.callables import Unary, UnaryContract
from fp.iteration import find_map_effect
from std.testing import assert_equal

@fieldwise_init
struct EvenText(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[String]]
    def call(self, var value: Int) -> Self.Out:
        return Optional(Optional(String(value)) if value % 2 == 0 else Optional[String]())

def forward[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FindMapContract[I, V, F].Error -> FindMapContract[I, V, F].Out where FindMapContract[I, V, F].Compatible:
    return find_map_effect[I](function^, source^)

def main() raises:
    var result = forward[OptionalFamily](EvenText(), List[Int]([1, 2, 4]))
    assert_equal(result.value().value(), "2")
    print("first match:", result.value().value())
