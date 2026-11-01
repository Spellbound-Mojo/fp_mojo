from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.callables import Unary
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct IterOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct IterReject[V: Movable & Deinitable, E: Copyable & Deinitable](Unary):
    var failure: Self.E
    comptime Arg = Self.V
    comptime Out = Result[Self.V, Self.E]
    def call(self, var value: Self.Arg) -> Self.Out: return Err(self.failure.copy())


def owners(drops: ArcPointer[Int]) -> List[IterOwner]:
    var values = List[IterOwner]()
    for i in range(3): values.append(IterOwner(i, drops))
    return values^


def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def keep(var value: View) -> Optional[View]: return Optional(value)
    var values = iterated(List[View]([view])).traverse(keep)
    comptime assert type_of(values) == Optional[List[View]]
    assert_equal(Pointer(to=values.value()[0][0]) == Pointer(to=owner[0]), True)
    var failed = iterated(List[View]([view])).traverse(IterReject[View, Failure](error))
    var stored = failed^.swap().to_optional()
    comptime assert type_of(stored) == Optional[Failure]
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]), True)
    var discarded = iterated(List[View]([view])).traverse_void(IterReject[View, Failure](error))
    var stored_void = discarded^.swap().to_optional()
    comptime assert type_of(stored_void) == Optional[Failure]
    assert_equal(Pointer(to=stored_void.value()[0]) == Pointer(to=other[0]), True)


def main() raises:
    var inputs = ArcPointer(0)
    def stop(var value: IterOwner) -> Optional[IterOwner]:
        if value.id == 1: return None
        return Optional(value^)
    assert_equal(Bool(iterated(owners(inputs)).traverse(stop)), False)
    assert_equal(inputs[], 3)
    assert_equal(Bool(iterated(owners(inputs)).traverse_void(stop)), False)
    assert_equal(inputs[], 6)
    def keep(var value: IterOwner) -> Optional[IterOwner]: return Optional(value^)
    var output = iterated(owners(inputs)).traverse(keep)
    assert_equal(output.value()[2].id, 2)
    assert_equal(inputs[], 6)
    _ = output^
    assert_equal(inputs[], 9)
    assert_equal(Bool(iterated(owners(inputs)).traverse_void(keep)), True)
    assert_equal(inputs[], 12)

    var failures = ArcPointer(0)
    def fail(var value: IterOwner) -> Result[IterOwner, IterOwner]: return Err(value^)
    var failed = iterated(owners(failures)).traverse(fail)
    assert_equal(failures[], 2)
    _ = failed^
    assert_equal(failures[], 3)
    var failed_void = iterated(owners(failures)).traverse_void(fail)
    assert_equal(failures[], 5)
    _ = failed_void^
    assert_equal(failures[], 6)

    def raise_owned(var value: IterOwner) raises IterOwner -> Optional[Int]: raise value^
    for discard in [False, True]:
        var raised = ArcPointer(0)
        var caught = False
        try:
            if discard: _ = iterated(owners(raised)).traverse_void(raise_owned)
            else: _ = iterated(owners(raised)).traverse(raise_owned)
        except failure:
            comptime assert type_of(failure) == IterOwner
            assert_equal(raised[], 2)
            caught = failure.id == 0
        assert_equal(caught, True)
        assert_equal(raised[], 3)

    var captures = ArcPointer(0)
    var capture = IterOwner(9, captures)
    def closure(var value: Int) {var capture^} -> Optional[Int]: return Optional(value + capture.id)
    assert_equal(iterated(range(2)).traverse(closure).value(), [9, 10])
    assert_equal(Bool(iterated(range(2)).traverse_void(closure)), True)
    assert_equal(closure(2).value(), 11)
    assert_equal(captures[], 0)
    _ = closure^
    assert_equal(captures[], 1)
    origins([3], [7])
