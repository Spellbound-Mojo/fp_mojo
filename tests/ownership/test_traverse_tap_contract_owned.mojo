"""Generic borrowing traversal retains owners and independent origins."""
from algebra_support.tap_contracts import observed
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from test_iter_inferred_traversal_owned import IterOwner, owners
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.callables import BorrowSignature
from std.memory import ArcPointer
from std.testing import assert_equal

def keep(value: IterOwner) -> Optional[NoneType]: return Optional(NoneType())
def stop(value: IterOwner) -> Optional[NoneType]:
    if value.id == 1: return None
    return Optional(NoneType())

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def observe(value: View) -> Optional[NoneType]: return Optional(NoneType())
    var gathered = observed[ListFamily,OptionalFamily](List[View]([view]),BorrowSignature[View,Optional[NoneType],Never].capture(observe))
    comptime assert type_of(gathered) == Optional[List[View]]
    assert_equal(Pointer(to=gathered.value()[0][0]) == Pointer(to=owner[0]),True)
    def fail(value: View) {error} -> Result[NoneType,Failure]: return Err(error)
    var failed = observed[ListFamily,ResultFamily[Failure]](List[View]([view]),BorrowSignature[View,Result[NoneType,Failure],Never].capture(fail))
    var stored = failed^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var kept = observed[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[NoneType],Never].capture(keep))
    assert_equal(drops[],0)
    assert_equal(kept.value()[2].id,2)
    _ = kept^
    assert_equal(drops[],3)
    assert_equal(Bool(observed[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[NoneType],Never].capture(stop))),False)
    assert_equal(drops[],6)
    var errors = ArcPointer(0)
    def raise_error(value: IterOwner) raises IterOwner {errors} -> Optional[NoneType]:
        raise IterOwner(value.id,errors)
    var caught = -1
    try: _ = observed[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[NoneType],IterOwner].capture(raise_error))
    except failure:
        comptime assert type_of(failure) == IterOwner
        assert_equal(errors[],0)
        caught = failure.id
    assert_equal(caught,0)
    assert_equal(drops[],9)
    assert_equal(errors[],1)
    var capture = IterOwner(9,drops)
    def closure(value: IterOwner) {var capture^} -> Optional[Int]: return Optional(value.id + capture.id)
    var captured = observed[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[Int]].capture(closure^))
    assert_equal(captured.value()[0].id,0)
    assert_equal(drops[],10)
    _ = captured^
    assert_equal(drops[],13)
    origins([3],[7])
