"""Filtering moves accepted inputs and destroys discarded owners exactly once."""
from test_iter_inferred_traversal_owned import IterOwner, owners
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.callables import BorrowSignature
from std.memory import ArcPointer
from std.testing import assert_equal

def keep(value: IterOwner) -> Optional[Bool]: return Optional(value.id % 2 == 0)
def stop(value: IterOwner) -> Optional[Bool]:
    if value.id == 1: return None
    return Optional(True)

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def observe(value: View) -> Optional[Bool]: return Optional(True)
    var gathered = iterated(List[View]([view])).filter_effect(BorrowSignature[View,Optional[Bool],Never].capture(observe))
    comptime assert type_of(gathered) == Optional[List[View]]
    assert_equal(Pointer(to=gathered.value()[0][0]) == Pointer(to=owner[0]),True)
    def fail(value: View) {error} -> Result[Bool,Failure]: return Err(error)
    var failed = iterated(List[View]([view])).filter_effect(BorrowSignature[View,Result[Bool,Failure],Never].capture(fail))
    var stored = failed^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var kept = iterated(owners(drops)).filter_effect(BorrowSignature[IterOwner,Optional[Bool],Never].capture(keep))
    assert_equal(drops[],1)
    assert_equal(kept.value()[1].id,2)
    _ = kept^
    assert_equal(drops[],3)
    assert_equal(Bool(iterated(owners(drops)).filter_effect(BorrowSignature[IterOwner,Optional[Bool],Never].capture(stop))),False)
    assert_equal(drops[],6)
    var errors = ArcPointer(0)
    def raise_error(value: IterOwner) raises IterOwner {errors} -> Optional[Bool]:
        raise IterOwner(value.id,errors)
    var caught = -1
    try: _ = iterated(owners(drops)).filter_effect(BorrowSignature[IterOwner,Optional[Bool],IterOwner].capture(raise_error))
    except failure:
        comptime assert type_of(failure) == IterOwner
        assert_equal(errors[],0)
        caught = failure.id
    assert_equal(caught,0)
    assert_equal(drops[],9)
    assert_equal(errors[],1)
    var capture = IterOwner(2,drops)
    def closure(value: IterOwner) {var capture^} -> Optional[Bool]: return Optional(value.id < capture.id)
    var captured = iterated(owners(drops)).filter_effect(BorrowSignature[IterOwner,Optional[Bool]].capture(closure^))
    assert_equal(captured.value()[0].id,0)
    assert_equal(drops[],11)
    _ = captured^
    assert_equal(drops[],13)
    origins([3],[7])
