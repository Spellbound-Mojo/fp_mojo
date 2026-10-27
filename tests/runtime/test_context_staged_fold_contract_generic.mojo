from context_staged_fold_contract_support import forward, OriginStep
from context_fold_contract_support import Add, SumOwned, Fallible, owned_items
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def origins[o: ImmOrigin](ref[o] error: Int) raises:
    var caught = False
    try:
        _ = forward[OptionalFamily](Fallible[OptionalFamily, o](Pointer(to=error)), 0, List[Int]([1, -1]))
    except raised:
        comptime assert type_of(raised) == Pointer[Int, o]
        caught = raised == Pointer(to=error)
    assert_equal(caught, True)

def retained_origin[o: ImmOrigin](ref[o] value: Int) raises:
    var seed: List[Pointer[Int, o]] = [Pointer(to=value)]
    var retained = forward[OptionalFamily](OriginStep[o](), seed^, List[Int]([1])).get()
    assert_equal(retained.value()[0] == Pointer(to=value), True)

def main() raises:
    assert_equal(forward[IdentityFamily](SumOwned[IdentityFamily](), 10, owned_items()).get(), 13)
    assert_equal(forward[OptionalFamily](SumOwned[OptionalFamily](), 10, owned_items()).get().value(), 13)
    assert_equal(forward[ListFamily](Add[ListFamily](), 10, List[Int]([1, 2])).get(), List[Int]([13]))
    assert_equal(forward[ResultFamily[String]](Add[ResultFamily[String]](), 10, List[Int]()).get()._ok().value, 10)
    assert_equal(forward[BoxMonad](Add[BoxMonad](), 10, List[Int]([1, 2])).get().value, 13)
    var error = 71
    origins(error)
    var value = 23
    retained_origin(value)
