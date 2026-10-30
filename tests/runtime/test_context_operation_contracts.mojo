"""Operation contracts forward opaque families, exact errors and deferred types."""
from fp.algebra import Functor, Monad, MapContract, BindContract, ListFamily, OptionalFamily, StringMonoid
from fp.algebra import map, flat_map
from fp.callables import UnaryContract, Unary
from fp.functions import pipeline, Identity
from fp.effects import Writer, ReaderT, LiftListen, listen, run_writer, run
from algebra_support.external import PublicMonad
from std.testing import assert_equal

def mapped[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises MapContract[I, V, F].Error -> MapContract[I, V, F].Out where MapContract[I, V, F].Compatible:
    return pipeline[I](value^).map(function^).get()

def bound[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises BindContract[I, V, F].Error -> BindContract[I, V, F].Out where BindContract[I, V, F].Compatible:
    return pipeline[I](value^).flat_map(function^).get()

# Existing generic proof syntax still forwards to the new shared contracts.
def legacy_map[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises I.MapError[V, F] -> I.Mapped[V, F] where I.Element[V] == F.Arg and I.MapCompatible[V, F]:
    return map[I](value^, function^)

@fieldwise_init
struct Present[T: Movable & Deinitable](Unary):
    comptime Arg = Self.T
    comptime Out = Optional[Self.T]
    def call(self, var value: Self.T) -> Self.Out: return Optional(value^)

def main() raises:
    assert_equal(mapped[ListFamily](List[Int]([1, 2]), Identity[Int]()), [1, 2])
    assert_equal(legacy_map[ListFamily](List[Int]([1, 2]), Identity[Int]()), [1, 2])
    assert_equal(bound[OptionalFamily](Optional(3), Present[Int]()).value(), 3)
    # The error belongs to the operation, not just the callback.
    var code = 0
    try: _ = mapped[PublicMonad[OptionalFamily, 1]](Optional(3), Identity[Int]())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 702)
    try: _ = bound[PublicMonad[OptionalFamily, 2]](Optional(3), Present[Int]())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 703)
    # These nested projections must remain lazy until the family is known.
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    comptime RC = LiftListen[R, W]
    var action = listen[RC](R.pure(8))
    var result = mapped[R](action^, Identity[Tuple[Int, String]]())
    assert_equal(run_writer[W](run[R](result^, 0))[1][0], 8)
    origins(List[Int]([7, 9]))

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var result = mapped[ListFamily](List[View]([Span(owner)]), Identity[View]())
    comptime assert type_of(result) == List[View]
    assert_equal(result[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    var next = bound[OptionalFamily](Optional(Span(owner)), Present[View]())
    comptime assert type_of(next) == Optional[View]
    assert_equal(next.value().unsafe_ptr() == Span(owner).unsafe_ptr(), True)
