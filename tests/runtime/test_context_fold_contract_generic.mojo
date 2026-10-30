from context_fold_contract_support import Owned, SumOwned, Add, Fallible, owned_items
from fp.algebra import FoldContract, Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from fp.callables import BinaryContract
from fp.iteration import fold_effect, iterated
from fp.functions import piped
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def forward[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> FoldContract[I, V, F].Out where FoldContract[I, V, F].Compatible:
    return fold_effect[I](source^, initial^, function^)

def fluent[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> FoldContract[I, V, F].Out where FoldContract[I, V, F].Compatible:
    return piped(source^).fold_effect[I](function^, initial^).get()

def origins[o: ImmOrigin](ref[o] error: Int) raises:
    var caught = False
    try:
        _ = forward[OptionalFamily](Fallible[OptionalFamily, o](Pointer(to=error)), 0, List[Int]([1, -1]))
    except raised:
        comptime assert type_of(raised) == Pointer[Int, o]
        caught = raised == Pointer(to=error)
    assert_equal(caught, True)

def main() raises:
    assert_equal(forward[IdentityFamily](SumOwned[IdentityFamily](), 10, owned_items()), 13)
    assert_equal(fluent[OptionalFamily](SumOwned[OptionalFamily](), 10, owned_items()).value(), 13)
    comptime assert not FoldContract[ListFamily, List[Owned], SumOwned[ListFamily]].Compatible
    assert_equal(forward[ListFamily](Add[ListFamily](), 10, List[Int]([1, 2])), List[Int]([13]))
    assert_equal(forward[ResultFamily[String]](Add[ResultFamily[String]](), 10, List[Int]())._ok().value, 10)
    assert_equal(forward[BoxMonad](Add[BoxMonad](), 10, List[Int]([1, 2])).value, 13)
    assert_equal(iterated(List[Int]([1, 2])).fold_effect[OptionalFamily](Add[OptionalFamily](), 10).value(), 13)
    var error = 71
    origins(error)
