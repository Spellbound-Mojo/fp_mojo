from fp.algebra import Monad, Monoid, OptionalFamily, StringMonoid
from fp.algebra.contracts import FoldMapContract
from fp.callables import Unary, UnaryContract
from fp.iteration import fold_map_effect
from std.testing import assert_equal

@fieldwise_init
struct Text(Unary):
    comptime Arg = Int
    comptime Out = Optional[String]
    def call(self, var value: Int) -> Self.Out:
        return Optional(String(value))

def forward[I: Monad, M: Monoid, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FoldMapContract[I, M, V, F].Error -> FoldMapContract[I, M, V, F].Out where FoldMapContract[I, M, V, F].Compatible:
    return fold_map_effect[M, I](source^, function^)

def main() raises:
    var result = forward[OptionalFamily, StringMonoid](Text(), List[Int]([1, 2]))
    assert_equal(result.value(), "12")
    print("mapped fold:", result.value())
