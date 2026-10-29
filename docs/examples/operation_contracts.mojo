"""Public contracts name generic operation admission, results and native errors."""
from fp.algebra import Functor, MapContract, FillContract, VoidContract, TupleRightContract, Applicative, Traversable, TraverseContract, ListFamily, OptionalFamily
from fp.callables import UnaryContract, Unary
from fp.functions import pipeline, Identity
from std.testing import assert_equal

def mapped[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where MapContract[I,V,F].InvocationCompatible:
    return pipeline[I](value^).map(function^).get()


def gather[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var values: V, var function: F
) raises TraverseContract[S, G, V, F].Error -> TraverseContract[S, G, V, F].Out where TraverseContract[S, G, V, F].Compatible:
    return pipeline[S](values^).traverse[G](function^).get()


def filled[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable](
    var source: V, var replacement: U
) raises FillContract[I,V,U].Error -> FillContract[I,V,U].Out where FillContract[I,V,U].InvocationCompatible:
    return pipeline[I](source^).fill(replacement^).get()


def discarded[I: Functor, V: Movable & Deinitable](
    var source: V
) raises VoidContract[I,V].Error -> VoidContract[I,V].Out where VoidContract[I,V].InvocationCompatible:
    return pipeline[I](source^).void().get()

@fieldwise_init
struct Positive(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Self.Out:
        return Optional(value) if value > 0 else None


def attached[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable](
    var source: V, var value: U
) raises TupleRightContract[I, V, U].Error -> TupleRightContract[I, V, U].Out where TupleRightContract[I, V, U].InvocationCompatible:
    return pipeline[I](source^).tuple_right(value^).get()

def main() raises:
    assert_equal(mapped[OptionalFamily](Optional(3), Identity[Int]()).value(), 3)
    var result = gather[ListFamily, OptionalFamily](List[Int]([3, 7]), Positive())
    var values = result.take()
    assert_equal(values, List[Int]([3, 7]))
    print("gathered:", values[0], values[1])
    var replacement: List[Int] = [7, 11]
    var output = filled[OptionalFamily](Optional(0), replacement^)
    ref filled_values = output.value()
    print("filled:", filled_values[0], filled_values[1])
    var done = discarded[OptionalFamily](output^)
    print("discarded:", Bool(done))
    var attached_values: List[Int] = [7, 11]
    var paired = attached[OptionalFamily](Optional(3), attached_values^)
    ref pair = paired.value()
    print("attached:", pair[0], pair[1])
