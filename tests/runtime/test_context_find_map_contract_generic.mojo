"""Public first-match proofs preserve stopping, ownership and native origins."""
from context_find_map_contract_support import forward, fluent, iterator_forward, selected, Text, Owned, OwnedQuery, OnceText, Branches, Borrowed, Later
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from fp.algebra.contracts import FindMapContract
from fp.iteration import iterated
from fp.effects import Reader, run
from algebra_support.box import BoxMonad
from std.memory import ArcPointer
from std.testing import assert_equal

def origins[v: ImmOrigin, e: ImmOrigin](ref[v] value: Int, ref[e] failure: Int) raises:
    var selected: Optional[Optional[Pointer[Int, v]]]
    try:
        selected = forward[OptionalFamily](Borrowed[OptionalFamily, v, e](Pointer(to=failure)), List[Pointer[Int, v]]([Pointer(to=value)]))
    except _:
        raise Error("unexpected origin failure")
    assert_equal(selected.value().value() == Pointer(to=value), True)

def error_origin[v: ImmOrigin, e: ImmOrigin](ref[v] value: Int, ref[e] failure: Int) raises:
    var caught = False
    try:
        _ = forward[OptionalFamily](Borrowed[OptionalFamily, v, e](Pointer(to=failure)), List[Pointer[Int, v]]([Pointer(to=value)]))
    except error:
        comptime assert type_of(error) == Pointer[Int, e]
        caught = error == Pointer(to=failure)
    assert_equal(caught, True)

def extended() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source: List[Owned] = [Owned(1, drops), Owned(2, drops), Owned(3, drops)]
    var result = forward[OptionalFamily](OwnedQuery[OptionalFamily](Owned(9, drops), calls), source^)
    assert_equal(result.value().value().id, 2)
    assert_equal(calls[], 2)
    assert_equal(drops[], 3)
    _ = result^
    assert_equal(drops[], 4)
    comptime assert not FindMapContract[ListFamily, List[Owned], OwnedQuery[ListFamily]].Compatible
    comptime assert not FindMapContract[OptionalFamily, List[Int], OnceText].Compatible
    calls[] = 0
    var branches = forward[ListFamily](Branches(calls), List[Int]([1, 2]))
    assert_equal(len(branches), 3)
    assert_equal(branches[0].value(), "1")
    assert_equal(branches[1].value(), "2")
    assert_equal(Bool(branches[2]), False)
    assert_equal(calls[], 2)
    calls[] = 0
    var pending = forward[Reader[Int]](Later(calls), List[Int]([1, 2, 3]))
    assert_equal(calls[], 0)
    var output: Optional[String]
    try:
        output = run[Reader[Int]](pending^, 0)
    except _:
        raise Error("unexpected deferred error")
    assert_equal(output.value(), "2")
    assert_equal(calls[], 2)
    var abandoned = forward[Reader[Int]](Later(calls), List[Int]([1, 2, 3]))
    _ = abandoned^
    assert_equal(calls[], 2)
    var failing = forward[Reader[Int]](Later(calls), List[Int]([1, -2, 3]))
    var code = 0
    try:
        _ = run[Reader[Int]](failing^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, -2)
    assert_equal(calls[], 4)
    var value = 2
    var failure = 7
    var negative = -1
    origins(value, failure)
    error_origin(negative, failure)

def main() raises:
    assert_equal(forward[IdentityFamily](Text[IdentityFamily](), List[Int]([1, 2, 3])).value(), "2")
    assert_equal(fluent[OptionalFamily](Text[OptionalFamily](), List[Int]([1, 2, 3])).value().value(), "2")
    assert_equal(iterator_forward[OptionalFamily](Text[OptionalFamily](), iterated(List[Int]([1, 2, 3]))).value().value(), "2")
    assert_equal(selected[OptionalFamily](Text[OptionalFamily](), List[Int]([1, 2, 3])).get().value().value(), "2")
    assert_equal(forward[ListFamily](Text[ListFamily](), List[Int]([1, 2, 3]))[0].value(), "2")
    assert_equal(forward[BoxMonad](Text[BoxMonad](), List[Int]([1, 2, 3])).value.value(), "2")
    assert_equal(Bool(forward[ResultFamily[String]](Text[ResultFamily[String]](), List[Int]())._ok().value), False)
    extended()
