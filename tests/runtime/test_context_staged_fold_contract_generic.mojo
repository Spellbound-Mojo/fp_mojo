from context_staged_fold_contract_support import forward, checked, MissingFoldReceiver, OriginStep
from context_fold_contract_support import Add, Once, SumOwned, Fallible, owned_items
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from fp.algebra.contracts import FoldContract
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def origins[o: ImmOrigin](ref[o] error: Int) raises:
    var caught = False
    try:
        _ = checked[OptionalFamily](Fallible[OptionalFamily, o](Pointer(to=error)), 0, List[Int]([1, -1]))
    except raised:
        comptime assert type_of(raised) == Pointer[Int, o]
        caught = raised == Pointer(to=error)
    assert_equal(caught, True)

def retained_origin[o: ImmOrigin](ref[o] value: Int) raises:
    var seed: List[Pointer[Int, o]] = [Pointer(to=value)]
    var retained = checked[OptionalFamily](OriginStep[o](), seed^, List[Int]([1])).get()
    assert_equal(retained.value()[0] == Pointer(to=value), True)

def main() raises:
    # Custom fold policies keep their original admission; the optional proof
    # checks repeatability independently before a wrapper calls the stage.
    comptime assert FoldContract[BoxMonad, List[Int], MissingFoldReceiver[BoxMonad]].Compatible
    comptime assert not FoldContract[BoxMonad, List[Int], MissingFoldReceiver[BoxMonad]].InvocationCompatible
    comptime assert FoldContract[BoxMonad, List[Int], Once[BoxMonad]].Compatible
    comptime assert not FoldContract[BoxMonad, List[Int], Once[BoxMonad]].ReceiverCompatible
    assert_equal(checked[IdentityFamily](SumOwned[IdentityFamily](), 10, owned_items()).get(), 13)
    assert_equal(checked[OptionalFamily](SumOwned[OptionalFamily](), 10, owned_items()).get().value(), 13)
    assert_equal(checked[ListFamily](Add[ListFamily](), 10, List[Int]([1, 2])).get(), List[Int]([13]))
    assert_equal(checked[ResultFamily[String]](Add[ResultFamily[String]](), 10, List[Int]()).get()._ok().value, 10)
    assert_equal(checked[BoxMonad](Add[BoxMonad](), 10, List[Int]([1, 2])).get().value, 13)
    assert_equal(forward[IdentityFamily](SumOwned[IdentityFamily](), 10, owned_items()).get(), 13)
    assert_equal(forward[OptionalFamily](SumOwned[OptionalFamily](), 10, owned_items()).get().value(), 13)
    assert_equal(forward[ListFamily](Add[ListFamily](), 10, List[Int]([1, 2])).get(), List[Int]([13]))
    assert_equal(forward[ResultFamily[String]](Add[ResultFamily[String]](), 10, List[Int]()).get()._ok().value, 10)
    assert_equal(forward[BoxMonad](Add[BoxMonad](), 10, List[Int]([1, 2])).get().value, 13)
    var error = 71
    origins(error)
    var value = 23
    retained_origin(value)
