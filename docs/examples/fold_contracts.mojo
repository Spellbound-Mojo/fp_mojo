from fp.algebra import FoldContract, Monad, OptionalFamily, IdentityFamily
from fp.callables import BinaryContract, Binary, RepeatableBinary
from fp.functions import pipeline, Pipeline
from fp.iteration import fold_effect
from std.testing import assert_equal

@fieldwise_init
struct Add(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Optional[Int]
    def call(self, var first: Int, var second: Int) -> Self.Out:
        return Optional(first + second)

def forward[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> FoldContract[I, V, F].Out where FoldContract[I, V, F].Compatible:
    return fold_effect[I](function^, initial^, source^)

def staged[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> Pipeline[I, FoldContract[I, V, F].Out] where FoldContract[I, V, F].Compatible and RepeatableBinary[F]:
    return pipeline[IdentityFamily](source^).fold_effect[I](initial^).run(function^)

def main() raises:
    var result = forward[OptionalFamily](Add(), 10, List[Int]([1, 2]))
    assert_equal(result.value(), 13)
    print("folded:", result.value())
    var selected = staged[OptionalFamily](Add(), 10, List[Int]([1, 2])).get()
    assert_equal(selected.value(), 13)
    print("staged:", selected.value())
