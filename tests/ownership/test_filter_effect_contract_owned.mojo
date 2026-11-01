"""Filtering moves accepted inputs and destroys discarded owners exactly once."""
from algebra_support.filter_effect_contracts import filtered
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import BorrowOnceCallable
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
    var gathered = filtered[ListFamily,OptionalFamily](List[View]([view]),BorrowSignature[View,Optional[Bool],Never].capture(observe))
    comptime assert type_of(gathered) == Optional[List[View]]
    assert_equal(Pointer(to=gathered.value()[0][0]) == Pointer(to=owner[0]),True)
    def fail(value: View) {error} -> Result[Bool,Failure]: return Err(error)
    var failed = filtered[ListFamily,ResultFamily[Failure]](List[View]([view]),BorrowSignature[View,Result[Bool,Failure],Never].capture(fail))
    var stored = failed^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)

@fieldwise_init
struct Single[accepted: Bool](BorrowOnceCallable):
    var capture: IterOwner
    comptime Payload = IterOwner
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: IterOwner) -> Self.Result:
        return Optional(Self.accepted and self.capture.id == 9)

def single[accepted: Bool]() raises:
    var drops = ArcPointer(0)
    var kept = filtered[OptionalFamily,OptionalFamily](Optional(IterOwner(2,drops)),Single[accepted](IterOwner(9,drops)))
    assert_equal(drops[],1 if accepted else 2)
    assert_equal(Bool(kept.value()),accepted)
    comptime if accepted: assert_equal(kept.value().value().id,2)
    _ = kept^
    assert_equal(drops[],2)
    var absent = filtered[OptionalFamily,OptionalFamily](Optional[IterOwner](),Single[True](IterOwner(9,drops)))
    assert_equal(Bool(absent.value()),False)
    assert_equal(drops[],3)

def main() raises:
    single[True]()
    single[False]()
    var drops = ArcPointer(0)
    var kept = filtered[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[Bool],Never].capture(keep))
    assert_equal(drops[],1)
    assert_equal(kept.value()[1].id,2)
    _ = kept^
    assert_equal(drops[],3)
    assert_equal(Bool(filtered[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[Bool],Never].capture(stop))),False)
    assert_equal(drops[],6)
    var errors = ArcPointer(0)
    def raise_error(value: IterOwner) raises IterOwner {errors} -> Optional[Bool]:
        raise IterOwner(value.id,errors)
    var caught = -1
    try: _ = filtered[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[Bool],IterOwner].capture(raise_error))
    except failure:
        comptime assert type_of(failure) == IterOwner
        assert_equal(errors[],0)
        caught = failure.id
    assert_equal(caught,0)
    assert_equal(drops[],9)
    assert_equal(errors[],1)
    var capture = IterOwner(2,drops)
    def closure(value: IterOwner) {var capture^} -> Optional[Bool]: return Optional(value.id < capture.id)
    var captured = filtered[ListFamily,OptionalFamily](owners(drops),BorrowSignature[IterOwner,Optional[Bool]].capture(closure^))
    assert_equal(captured.value()[0].id,0)
    assert_equal(drops[],11)
    _ = captured^
    assert_equal(drops[],13)
    origins([3],[7])
