"""Combines move-only contents and releases partial, unread and deferred owners."""
from fp.functions import pipeline
from fp.algebra import ListMonoid
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CombineOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def one(id: Int, drops: ArcPointer[Int]) -> List[CombineOwner]:
    var items = List[CombineOwner]()
    items.append(CombineOwner(id, drops))
    return items^

def main() raises:
    var drops = ArcPointer(0)
    var groups = List[Optional[List[CombineOwner]]]()
    groups.append(Optional(one(1, drops))); groups.append(Optional(one(2, drops)))
    var output = pipeline(groups^).combine_all_effect[ListMonoid[CombineOwner]]().get()
    assert_equal(len(output.value()), 2)
    assert_equal(output.value()[0].id, 1); assert_equal(output.value()[1].id, 2)
    assert_equal(drops[], 0)
    _ = output^
    assert_equal(drops[], 2)
    drops[] = 0
    var absent = List[Optional[List[CombineOwner]]]()
    absent.append(Optional(one(1, drops))); absent.append(Optional[List[CombineOwner]]()); absent.append(Optional(one(3, drops)))
    assert_equal(Bool(pipeline(absent^).combine_all_effect[ListMonoid[CombineOwner]]().get()), False)
    assert_equal(drops[], 2)
    drops[] = 0
    var errors = List[Result[List[CombineOwner], CombineOwner]]()
    errors.append(Ok(one(1, drops)))
    errors.append(Err(CombineOwner(2, drops)))
    errors.append(Ok(one(3, drops)))
    var failed = pipeline(errors^).combine_all_effect[ListMonoid[CombineOwner]]().get()
    assert_equal(failed._err().value.id, 2)
    assert_equal(drops[], 2)
    _ = failed^
    assert_equal(drops[], 3)
    comptime Deferred = Reader[Int]
    drops[] = 0
    var actions = List[Deferred.Pure[List[CombineOwner]]]()
    actions.append(Deferred.pure(one(1, drops))); actions.append(Deferred.pure(one(2, drops)))
    var pending = pipeline(actions^).combine_all_effect[Deferred, ListMonoid[CombineOwner]]().get()
    assert_equal(drops[], 0)
    var combined = run[Deferred](pending^, 0)
    assert_equal(len(combined), 2); assert_equal(drops[], 0)
    _ = combined^
    assert_equal(drops[], 2)
    drops[] = 0
    var unused = List[Deferred.Pure[List[CombineOwner]]]()
    unused.append(Deferred.pure(one(1, drops))); unused.append(Deferred.pure(one(2, drops)))
    var abandoned = pipeline(unused^).combine_all_effect[Deferred, ListMonoid[CombineOwner]]().get()
    assert_equal(drops[], 0)
    _ = abandoned^
    assert_equal(drops[], 2)
