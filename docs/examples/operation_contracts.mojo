"""One shared contract describes a generic traversal's admission and types."""
from fp.algebra import Applicative, Traversable, TraverseContract, ListFamily, OptionalFamily
from fp.callables import UnaryContract, Unary
from fp.functions import pipeline
from std.testing import assert_equal

def gather[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var values: V, var function: F
) raises TraverseContract[S, G, V, F].Error -> TraverseContract[S, G, V, F].Out where TraverseContract[S, G, V, F].Compatible:
    return pipeline[S](values^).traverse[G](function^).get()

@fieldwise_init
struct Positive(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Self.Out:
        return Optional(value) if value > 0 else None

def main() raises:
    var result = gather[ListFamily, OptionalFamily](List[Int]([3, 7]), Positive())
    var values = result.take()
    assert_equal(values, List[Int]([3, 7]))
    print("gathered:", values[0], values[1])
