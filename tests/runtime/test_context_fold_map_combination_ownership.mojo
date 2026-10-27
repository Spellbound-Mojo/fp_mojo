"""Mapped folds preserve owned callback, source, accumulator and error cleanup."""
from fp.algebra import FoldMapContract, Monad, Monoid, IdentityFamily, OptionalFamily, ResultFamily, pure
from fp.callables import MutableUnary
from fp.effects import Reader, run
from context_fold_map_contract_support import forward
from test_context_failure_forwarding_ownership import Owner
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.box import BoxMonad

struct Ordered[fail: Bool](Monoid):
    comptime Value = List[Owner]
    comptime Error = Owner
    @staticmethod
    def empty() -> Self.Value:
        return List[Owner]()
    @staticmethod
    def combine(var first: Self.Value, var second: Self.Value) raises Owner -> Self.Value:
        var id = second[0].id
        var trace = second[0].trace
        trace[] += "c" + String(id)
        if Self.fail and id == 2:
            raise Owner(8, trace)
        first.extend(second^)
        return first^

@fieldwise_init
struct Produce[G: Monad, fail: Bool](MutableUnary):
    var capture: Owner
    var calls: Int
    comptime Arg = Owner
    comptime Out = Self.G.Pure[List[Owner]]
    comptime Error = Owner
    def call_mut(mut self, var value: Owner) raises Owner -> Self.Out:
        self.calls += 1
        self.capture.trace[] += "p" + String(self.calls)
        if Self.fail and value.id == 2:
            raise Owner(7, self.capture.trace)
        var items = List[Owner]()
        items.append(value^)
        return pure[Self.G](items^)

def source(trace: ArcPointer[String]) -> List[Owner]:
    var result = List[Owner]()
    for id in range(1, 4):
        result.append(Owner(id, trace))
    return result^

def immediate[G: Monad, producer_fails: Bool, combine_fails: Bool]() -> String where FoldMapContract[G, Ordered[combine_fails], List[Owner], Produce[G, producer_fails]].Compatible and FoldMapContract[G, Ordered[combine_fails], List[Owner], Produce[G, producer_fails]].Error == Owner:
    var trace = ArcPointer(String())
    try:
        var result = forward[G, Ordered[combine_fails]](Produce[G, producer_fails](Owner(9, trace), 0), source(trace))
        trace[] += "r"
        _ = result^
    except error:
        comptime assert type_of(error) == Owner
        trace[] += "e" + String(error.id)
        _ = error^
    trace[] += "z"
    return trace[].copy()

def delayed[producer_fails: Bool, combine_fails: Bool, execute: Bool]() -> String:
    comptime G = Reader[Int]
    var trace = ArcPointer(String())
    try:
        var pending = forward[G, Ordered[combine_fails]](Produce[G, producer_fails](Owner(9, trace), 0), source(trace))
        trace[] += "d"
        if execute:
            var result = run[G](pending^, 0)
            trace[] += "r"
            _ = result^
        else:
            _ = pending^
    except error:
        comptime assert type_of(error) == Owner
        trace[] += "e" + String(error.id)
        _ = error^
    trace[] += "z"
    return trace[].copy()

def main() raises:
    assert_equal(immediate[IdentityFamily, False, False](), "p1c1p2c2p3c39r123z")
    assert_equal(immediate[IdentityFamily, True, False](), "p1c1p22193e77z")
    assert_equal(immediate[IdentityFamily, False, True](), "p1c1p2c22193e88z")
    assert_equal(immediate[OptionalFamily, False, False](), "p1c1p2c2p3c39r123z")
    assert_equal(immediate[OptionalFamily, True, False](), "p1c1p22193e77z")
    assert_equal(immediate[OptionalFamily, False, True](), "p1c1p2c22193e88z")
    assert_equal(immediate[ResultFamily[String], False, False](), "p1c1p2c2p3c39r123z")
    assert_equal(immediate[ResultFamily[String], True, False](), "p1c1p22193e77z")
    assert_equal(immediate[ResultFamily[String], False, True](), "p1c1p2c22193e88z")
    assert_equal(immediate[BoxMonad, False, False](), "p1c1p2c2p3c39r123z")
    assert_equal(immediate[BoxMonad, True, False](), "p1c1p22193e77z")
    assert_equal(immediate[BoxMonad, False, True](), "p1c1p2c22193e88z")
    assert_equal(delayed[False, False, True](), "dp1c1p2c2p3c39r123z")
    assert_equal(delayed[True, False, True](), "dp1c1p22193e77z")
    assert_equal(delayed[False, True, True](), "dp1c1p2c22193e88z")
    assert_equal(delayed[False, False, False](), "d9123z")
