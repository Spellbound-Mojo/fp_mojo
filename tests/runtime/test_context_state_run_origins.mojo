from context_state_run_support import Produce, Once, Length, Continue, LengthPlus
from fp.effects import State, StateFamily, StateAction, run
from fp.algebra import OptionalFamily, traverse, pure, map2
from std.testing import assert_equal

def compatible[o: ImmOrigin](ref[o] value: Int) raises:
    comptime I = State[Int]
    comptime F = Produce[o, o]
    comptime assert I.RunCompatible[I.Collected[List[Int], F]]
    comptime assert I.RunCompatible[I.Mapped[I.Collected[List[Int], F], Length]]
    comptime assert I.RunCompatible[I.Bound[I.Collected[List[Int], F], Continue]]
    comptime assert not I.RunCompatible[I.Collected[List[Int], Once]]
    var single = traverse[OptionalFamily, I](Once(), Optional(7))
    var result = run[I](single^, 8)
    assert_equal(result[0].value(), 7)
    assert_equal(result[1], 8)
    for item in [-1, 1]:
        var caught = False
        try:
            _ = run[I](I.collect(F(Pointer(to=value), Pointer(to=value)), List[Int]([item])), 8)
        except error:
            comptime assert type_of(error) == Pointer[Int, o]
            caught = error == Pointer(to=value)
        assert_equal(caught, True)
        caught = False
        var combined = map2[I](LengthPlus(), I.collect(F(Pointer(to=value), Pointer(to=value)), List[Int]([item])), pure[I](4))
        try:
            _ = run[I](combined^, 8)
        except error:
            comptime assert type_of(error) == Pointer[Int, o]
            caught = error == Pointer(to=value)
        assert_equal(caught, True)

def incompatible[a: ImmOrigin, b: ImmOrigin](ref[a] first: Int, ref[b] second: Int) where (
    not State[Int].RunCompatible[State[Int].Collected[List[Int], Produce[a,b]]] and
    not State[Int].RunCompatible[State[Int].Mapped[State[Int].Collected[List[Int], Produce[a,b]], Length]] and
    not State[Int].RunCompatible[State[Int].Bound[State[Int].Collected[List[Int], Produce[a,b]], Continue]]
):
    pass

def main() raises:
    var first = 1
    var second = 2
    incompatible(first, second)
    compatible(first)
    ownership()


def execute[I: StateFamily, V: StateAction](var action: V, var state: I.StateType
) raises V.Error -> V.Out where I.RunCompatible[V]:
    return run[I](action^, state^)

from std.memory import ArcPointer

@fieldwise_init
struct Owned(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def ownership() raises:
    var drops = ArcPointer(0)
    comptime I = State[Owned]
    var result = execute[I](pure[I](9), Owned(7, drops))
    assert_equal(result[0], 9)
    assert_equal(result[1].value, 7)
    _ = result^
    assert_equal(drops[], 1)
