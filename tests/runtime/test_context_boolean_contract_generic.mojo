"""Public Boolean-fold proofs preserve both stopping policies and native effects."""
from context_boolean_contract_support import some, every, fluent, iterator_forward, selected, all_fluent, any_iterator, any_selected, Absent
from context_find_contract_support import Even, OwnedPredicate, Branches, Borrowed, Later
from context_find_map_contract_support import Owned
from fp.algebra import AnyContract, AllContract, IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from fp.iteration import iterated
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.box import BoxMonad

def error_origin[v: ImmOrigin, e: ImmOrigin](ref[v] value: Int, ref[e] failure: Int) raises:
    var caught = False
    try:
        _ = some[OptionalFamily](Borrowed[OptionalFamily, v, e](Pointer(to=failure)), List[Pointer[Int, v]]([Pointer(to=value)]))
    except error:
        comptime assert type_of(error) == Pointer[Int, e]
        caught = error == Pointer(to=failure)
    assert_equal(caught, True)
    caught = False
    try:
        _ = selected[OptionalFamily](Borrowed[OptionalFamily, v, e](Pointer(to=failure)), List[Pointer[Int, v]]([Pointer(to=value)]))
    except error:
        comptime assert type_of(error) == Pointer[Int, e]
        caught = error == Pointer(to=failure)
    assert_equal(caught, True)

def extended() raises:
    assert_equal(all_fluent[OptionalFamily](Even[OptionalFamily](), List[Int]([2, 4])).value(), True)
    assert_equal(any_iterator[OptionalFamily](Even[OptionalFamily](), iterated(List[Int]([1, 2]))).value(), True)
    assert_equal(any_selected[OptionalFamily](Even[OptionalFamily](), List[Int]()).get().value(), False)
    assert_equal(some[BoxMonad](Even[BoxMonad](), List[Int]([1, 2])).value, True)
    assert_equal(every[ResultFamily[String]](Even[ResultFamily[String]](), List[Int]([2, 3]))._ok().value, False)
    var calls = ArcPointer(0)
    assert_equal(some[ListFamily](Branches(calls), List[Int]([1, 2])), List[Bool]([True, True, False]))
    assert_equal(calls[], 2)
    calls[] = 0
    assert_equal(every[ListFamily](Branches(calls), List[Int]([1, 2])), List[Bool]([True, False, False]))
    assert_equal(calls[], 2)
    calls[] = 0
    assert_equal(Bool(some[OptionalFamily](Absent(calls, False), List[Int]([1, 2, 3]))), False)
    assert_equal(calls[], 2)
    calls[] = 0
    assert_equal(Bool(every[OptionalFamily](Absent(calls, True), List[Int]([1, 2, 3]))), False)
    assert_equal(calls[], 2)
    calls[] = 0
    var drops = ArcPointer(0)
    var source: List[Owned] = [Owned(1, drops), Owned(2, drops), Owned(3, drops)]
    assert_equal(fluent[OptionalFamily](OwnedPredicate[OptionalFamily](Owned(9, drops), calls), source^).value(), True)
    assert_equal(calls[], 2)
    assert_equal(drops[], 4)
    calls[] = 0
    source = [Owned(2, drops), Owned(1, drops), Owned(3, drops)]
    assert_equal(selected[OptionalFamily](OwnedPredicate[OptionalFamily](Owned(9, drops), calls), source^).get().value(), False)
    assert_equal(calls[], 2)
    assert_equal(drops[], 8)
    comptime assert not AnyContract[ListFamily, List[Owned], OwnedPredicate[ListFamily]].Compatible
    comptime assert not AllContract[ListFamily, List[Owned], OwnedPredicate[ListFamily]].Compatible
    calls[] = 0
    var pending_any = some[Reader[Int]](Later(calls), List[Int]([1, 2, -3]))
    var pending_all = every[Reader[Int]](Later(calls), List[Int]([2, 4, -3]))
    assert_equal(calls[], 0)
    var any_result: Bool
    var all_result: Bool
    try:
        any_result = run[Reader[Int]](pending_any^, 0)
        all_result = run[Reader[Int]](pending_all^, 0)
    except _:
        raise Error("short-circuit visited a skipped failure")
    assert_equal(any_result, True)
    assert_equal(all_result, False)
    assert_equal(calls[], 4)
    var abandoned = some[Reader[Int]](Later(calls), List[Int]([1, 2]))
    _ = abandoned^
    assert_equal(calls[], 4)
    var failing = every[Reader[Int]](Later(calls), List[Int]([2, -2, 3]))
    var code = 0
    try:
        _ = run[Reader[Int]](failing^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, -2)
    assert_equal(calls[], 6)
    var negative = -1
    var failure = 7
    error_origin(negative, failure)

def main() raises:
    assert_equal(some[IdentityFamily](Even[IdentityFamily](), List[Int]([1, 2, 4])), True)
    assert_equal(every[IdentityFamily](Even[IdentityFamily](), List[Int]([2, 4])), True)
    assert_equal(fluent[OptionalFamily](Even[OptionalFamily](), List[Int]([1, 3])).value(), False)
    assert_equal(iterator_forward[OptionalFamily](Even[OptionalFamily](), iterated(List[Int]([2, 3]))).value(), False)
    assert_equal(selected[OptionalFamily](Even[OptionalFamily](), List[Int]()).get().value(), True)
    assert_equal(some[ListFamily](Even[ListFamily](), List[Int]()), List[Bool]([False]))
    extended()
