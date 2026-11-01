from test_iter_inferred_traversal_owned import IterOwner, owners
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

def keep(var value: IterOwner) -> Optional[IterOwner]: return Optional(value^)

def group(var value: IterOwner) -> Optional[List[IterOwner]]:
    var result = List[IterOwner]()
    result.append(value^)
    return Optional(result^)

def maybe(var value: IterOwner) -> Optional[Optional[IterOwner]]:
    if value.id == 1: return Optional(Optional[IterOwner]())
    return Optional(Optional(value^))

def fail(var value: IterOwner) -> Result[Int,IterOwner]: return Err(value^)

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    var gathered = iterated(List[Optional[View]]([Optional(view)])).sequence()
    comptime assert type_of(gathered) == Optional[List[View]]
    assert_equal(Pointer(to=gathered.value()[0][0]) == Pointer(to=owner[0]),True)
    var filtered = iterated(List[Optional[Optional[View]]]([Optional(Optional(view))])).sequence_filter()
    assert_equal(Pointer(to=filtered.value()[0][0]) == Pointer(to=owner[0]),True)
    var failed = iterated(List[Result[View,Failure]]([Result[View,Failure](Err(error))])).sequence_void()
    var stored = failed^.swap().to_optional()
    comptime assert type_of(stored) == Optional[Failure]
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var collected = iterated(owners(drops)).map(keep).sequence()
    assert_equal(drops[],0)
    assert_equal(collected.value()[2].id,2)
    _ = collected^
    assert_equal(drops[],3)
    _ = iterated(owners(drops)).map(keep).sequence_void()
    assert_equal(drops[],6)
    var flattened = iterated(owners(drops)).map(group).flat_sequence()
    assert_equal(drops[],6)
    assert_equal(flattened.value()[2].id,2)
    _ = flattened^
    assert_equal(drops[],9)
    var filtered = iterated(owners(drops)).map(maybe).sequence_filter()
    assert_equal(drops[],10)
    assert_equal(len(filtered.value()),2)
    _ = filtered^
    assert_equal(drops[],12)
    var failed = iterated(owners(drops)).map(fail).sequence()
    assert_equal(drops[],14)
    _ = failed^
    assert_equal(drops[],15)
    var failed_void = iterated(owners(drops)).map(fail).sequence_void()
    assert_equal(drops[],17)
    _ = failed_void^
    assert_equal(drops[],18)
    origins([3],[7])
