"""Public mapped-fold proofs preserve ownership, origins and execution timing."""
from context_fold_map_contract_support import forward, fluent, iterator_forward, selected, Text, Owned, OwnedSum, ProduceOwned, ProduceSource, OnceText, Branches, Borrowed, FallibleMonoid, Later, CountingText
from fp.algebra import FoldMapContract, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, StringMonoid, ListMonoid
from fp.iteration import iterated
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

def origins[v: ImmOrigin, e: ImmOrigin](ref[v] value: Int, ref[e] failure: Int) raises:
    comptime M = ListMonoid[Pointer[Int, v]]
    var result: Optional[List[Pointer[Int, v]]]
    try: result = forward[OptionalFamily, M](Borrowed[OptionalFamily, v, e](Pointer(to=value), Pointer(to=failure)), List[Int]([1, 2]))
    except _: raise Error("unexpected origin failure")
    assert_equal(len(result.value()), 2)
    assert_equal(result.value()[0] == Pointer(to=value), True)
    var caught = False
    try: _ = forward[OptionalFamily, M](Borrowed[OptionalFamily, v, e](Pointer(to=value), Pointer(to=failure)), List[Int]([-1]))
    except error:
        comptime assert type_of(error) == Pointer[Int, e]
        caught = error == Pointer(to=failure)
    assert_equal(caught, True)

def deferred() raises:
    comptime D = Reader[Int]
    var calls = ArcPointer(0)
    var code = 0
    try: _ = forward[D, FallibleMonoid[True]](Later(calls, 0), List[Int]([1, 2]))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 71)
    assert_equal(calls[], 0)
    comptime C = FoldMapContract[D, FallibleMonoid[False], List[Int], Later]
    comptime assert C.Error == Int
    var pending: C.Out
    try: pending = forward[D, FallibleMonoid[False]](Later(calls, 0), List[Int]([1, 2]))
    except _: raise Error("unexpected initialization failure")
    assert_equal(calls[], 0)
    var output: String
    try: output = run[D](pending^, 0)
    except _: raise Error("unexpected deferred failure")
    assert_equal(output, "12")
    assert_equal(calls[], 2)
    try: pending = forward[D, FallibleMonoid[False]](Later(calls, 2), List[Int]([1, 2]))
    except _: raise Error("unexpected initialization failure")
    assert_equal(calls[], 2)
    try: _ = run[D](pending^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 73)
    assert_equal(calls[], 4)
    try: pending = forward[D, FallibleMonoid[False]](Later(calls, 0), List[Int]([1, -2, 3]))
    except _: raise Error("unexpected initialization failure")
    try: _ = run[D](pending^, 0)
    except error: code = error
    assert_equal(code, 72)
    assert_equal(calls[], 6)

def main() raises:
    assert_equal(forward[IdentityFamily, StringMonoid](Text[IdentityFamily](), List[Int]([1, 2])), "12")
    assert_equal(fluent[OptionalFamily, StringMonoid](Text[OptionalFamily](), List[Int]([1, 2])).value(), "12")
    assert_equal(forward[ListFamily, StringMonoid](Text[ListFamily](), List[Int]([1, 2])), List[String](["12"]))
    assert_equal(forward[ResultFamily[String], StringMonoid](Text[ResultFamily[String]](), List[Int]())._ok().value, "")
    assert_equal(iterator_forward[OptionalFamily, StringMonoid](Text[OptionalFamily](), iterated(List[Int]([1, 2]))).value(), "12")
    assert_equal(selected[OptionalFamily, StringMonoid](Text[OptionalFamily](), List[Int]([1, 2])).get().value(), "12")
    assert_equal(forward[IdentityFamily, OwnedSum](ProduceOwned[IdentityFamily](), List[Int]([1, 2])).value, 3)
    assert_equal(fluent[OptionalFamily, OwnedSum](ProduceOwned[OptionalFamily](), List[Int]([1, 2])).value().value, 3)
    var owned_source: List[Owned] = [Owned(1), Owned(2)]
    assert_equal(forward[OptionalFamily, StringMonoid](ProduceSource[OptionalFamily](), owned_source^).value(), "12")
    comptime assert not FoldMapContract[ListFamily, OwnedSum, List[Int], ProduceOwned[ListFamily]].Compatible
    comptime assert not FoldMapContract[ListFamily, StringMonoid, List[Owned], ProduceSource[ListFamily]].Compatible
    comptime assert not FoldMapContract[OptionalFamily, StringMonoid, List[Int], OnceText].Compatible
    assert_equal(forward[ListFamily, StringMonoid](Branches(), List[Int]([1, 2])), List[String](["1a2a", "1a2b", "1b2a", "1b2b"]))
    var value = 3
    var failure = 7
    origins(value, failure)
    assert_equal(forward[OptionalFamily, StringMonoid](CountingText(0), List[Int]([4, 5])).value(), "4:1;5:2;")
    deferred()
