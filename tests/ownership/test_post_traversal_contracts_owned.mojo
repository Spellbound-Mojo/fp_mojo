"""Checked traversal clients preserve move-only inputs, captures, errors and origins."""
from algebra_support.post_traversal_contracts import selected, flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import OnceUnary, as_unary
from fp.data import Result, Err
from test_iter_inferred_traversal_owned import IterOwner, owners
from std.memory import ArcPointer
from std.testing import assert_equal

def keep(var value: IterOwner) -> Optional[Optional[IterOwner]]:
    if value.id % 2: return Optional(Optional[IterOwner]())
    return Optional(Optional(value^))

def expand(var value: IterOwner) -> Optional[List[IterOwner]]:
    var output = List[IterOwner]()
    output.append(value^)
    return Optional(output^)

@fieldwise_init
struct Single(OnceUnary):
    var capture: IterOwner
    comptime Arg = IterOwner
    comptime Out = Optional[Optional[IterOwner]]
    def call_once(deinit self, var value: IterOwner) -> Self.Out:
        return Optional(Optional(value^))

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def keep_view(var value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    def group_view(var value: View) -> Optional[List[View]]: return Optional(List[View]([value]))
    var kept = selected[ListFamily,OptionalFamily](List[View]([view]),as_unary(keep_view))
    var grouped = flattened[ListFamily,OptionalFamily](List[View]([view]),as_unary(group_view))
    comptime assert type_of(kept) == Optional[List[View]]
    comptime assert type_of(grouped) == Optional[List[View]]
    assert_equal(Pointer(to=kept.value()[0][0]) == Pointer(to=owner[0]),True)
    assert_equal(Pointer(to=grouped.value()[0][0]) == Pointer(to=owner[0]),True)
    def reject(var value: View) {failure} -> Result[Optional[View],Failure]: return Err(failure)
    def reject_flat(var value: View) {failure} -> Result[List[View],Failure]: return Err(failure)
    var failed = selected[ListFamily,ResultFamily[Failure]](List[View]([view]),as_unary(reject))
    var failed_flat = flattened[ListFamily,ResultFamily[Failure]](List[View]([view]),as_unary(reject_flat))
    var stored = failed^.swap().to_optional()
    var stored_flat = failed_flat^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)
    assert_equal(Pointer(to=stored_flat.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var kept = selected[ListFamily,OptionalFamily](owners(drops),as_unary(keep))
    assert_equal(drops[],1)
    assert_equal(kept.value()[1].id,2)
    _ = kept^
    assert_equal(drops[],3)
    var grouped = flattened[ListFamily,OptionalFamily](owners(drops),as_unary(expand))
    assert_equal(drops[],3)
    assert_equal(len(grouped.value()),3)
    _ = grouped^
    assert_equal(drops[],6)
    var once = selected[OptionalFamily,OptionalFamily](Optional(IterOwner(2,drops)),Single(IterOwner(9,drops)))
    assert_equal(drops[],7)
    assert_equal(once.value().value().id,2)
    _ = once^
    assert_equal(drops[],8)
    var once_flat = flattened[OptionalFamily,OptionalFamily](Optional(IterOwner(2,drops)),Single(IterOwner(9,drops)))
    assert_equal(drops[],9)
    _ = once_flat^
    assert_equal(drops[],10)
    var errors = ArcPointer(0)
    def raise_owned(var value: IterOwner) raises IterOwner {errors} -> Optional[Optional[IterOwner]]:
        raise IterOwner(value.id,errors)
    try: _ = selected[ListFamily,OptionalFamily](owners(drops),as_unary(raise_owned))
    except failure:
        comptime assert type_of(failure) == IterOwner
        assert_equal(errors[],0)
        assert_equal(failure.id,0)
    assert_equal(drops[],13)
    assert_equal(errors[],1)
    origins([3],[7])
