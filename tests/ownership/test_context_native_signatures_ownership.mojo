"""Stored pointers are owned while payloads retain move-only and deferred semantics."""
from fp.functions import pipeline
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_native_nary_ownership import NaryOwner

def identity(var value: NaryOwner) -> NaryOwner: return value^
def changed(var value: NaryOwner) -> NaryOwner:
    value.id = -1
    return value^
def inspect(value: NaryOwner) -> Int: return value.id
def combine(var first: NaryOwner, var second: NaryOwner) -> NaryOwner:
    first.id += second.id
    return first^

def main() raises:
    comptime Deferred = Reader[Int]
    var drops = ArcPointer(0)
    var pointer: def(var NaryOwner) thin -> NaryOwner = identity
    var pending = pipeline[Deferred](Deferred.pure(NaryOwner(1, drops))).map(pointer).get()
    pointer = changed
    _ = pointer
    assert_equal(drops[], 0)
    var result = run[Deferred](pending^, 0)
    assert_equal(result.id, 1)
    _ = result^
    assert_equal(drops[], 1)
    var abandoned = pipeline[Deferred](Deferred.pure(NaryOwner(2, drops))).map(pointer).get()
    _ = abandoned^
    assert_equal(drops[], 2)
    var projection: def(NaryOwner) thin -> Int = inspect
    var paired = pipeline(Optional(NaryOwner(3, drops))).pair_with(projection).get()
    assert_equal(paired.value()[1], 3)
    assert_equal(drops[], 2)
    _ = paired^
    assert_equal(drops[], 3)
    var binary: def(var NaryOwner, var NaryOwner) thin -> NaryOwner = combine
    var combined = pipeline[Deferred](Deferred.pure(NaryOwner(4, drops))).map2(Deferred.pure(NaryOwner(5, drops)), binary).get()
    var sum = run[Deferred](combined^, 0)
    assert_equal(sum.id, 9)
    assert_equal(drops[], 4)
    _ = sum^
    assert_equal(drops[], 5)
    var values = List[NaryOwner]()
    values.append(NaryOwner(1, drops)); values.append(NaryOwner(2, drops))
    var reduced = pipeline(values^).reduce_optional(binary).get()
    assert_equal(reduced.value().id, 3)
    assert_equal(drops[], 6)
    _ = reduced^
    assert_equal(drops[], 7)
