"""Move-only elements, partial iteration and exact failure cleanup."""
from fp.data import NonEmptyList, Result, Ok, Err
from fp.algebra import NonEmptyListSemigroup, NonEmptyListFamily, ValidationFamily, map, traverse
from fp.callables import MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct NELOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def nelo_source(drops: ArcPointer[Int]) -> NonEmptyList[NELOwner]:
    var rest = List[NELOwner]()
    rest.append(NELOwner(2, drops))
    rest.append(NELOwner(3, drops))
    return NonEmptyList(NELOwner(1, drops), rest^)

def nelo_raise(var value: NELOwner) raises String -> NELOwner:
    if value.id == 2: raise String("native failure")
    return value^

@fieldwise_init
struct NELValidate(MutableUnary):
    var drops: ArcPointer[Int]
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Result[Int, NonEmptyList[NELOwner]]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        self.calls[] += 1
        return Err(NonEmptyList(NELOwner(arg, self.drops)))

def nelo_partial(drops: ArcPointer[Int]):
    var iterator = iter(nelo_source(drops))
    try:
        var first = iterator.__next__()
        _ = first^
    except:
        pass
    # Remaining elements are owned by the native iterator and destroyed here.

def main() raises:
    var drops = ArcPointer(0)
    nelo_partial(drops)
    assert_equal(drops[], 3)
    var raised = False
    try:
        _ = map[NonEmptyListFamily](nelo_raise, nelo_source(drops))
    except error:
        raised = True
        assert_equal(error, "native failure")
    assert_true(raised)
    assert_equal(drops[], 6)
    var joined = NonEmptyListSemigroup[NELOwner].combine(nelo_source(drops), nelo_source(drops))
    assert_equal(len(joined), 6)
    assert_equal(drops[], 6)
    _ = joined^
    assert_equal(drops[], 12)
    var calls = ArcPointer(0)
    var failed = traverse[NonEmptyListFamily, ValidationFamily[NonEmptyListSemigroup[NELOwner]]](
        NELValidate(drops, calls), NonEmptyList(1, List[Int]([2, 3])))
    assert_equal(calls[], 3)
    assert_equal(len(failed._err().value), 3)
    assert_equal(drops[], 12)
    _ = failed^
    assert_equal(drops[], 15)
    print("non-empty list ownership: ok")
