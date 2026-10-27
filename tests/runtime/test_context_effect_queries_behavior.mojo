"""Effectful terminals preserve empty defaults, source position and branch stopping."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, StringMonoid
from fp.data import Result, Ok, Err
from fp.callables import MutableUnary
from std.collections import Array, Deque
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.iterators import Counted
from test_combinators import CombinatorRestarting

def even(value: Int) -> Optional[Bool]: return Optional(value % 2 == 0)
def project(var value: Int) -> Optional[Optional[String]]:
    return Optional(Optional(String(value)) if value == 2 else Optional[String]())
def text(var value: Int) -> Optional[String]: return Optional(String(value))
def sum_step(var a: Int, var b: Int) -> Optional[Int]: return Optional(a + b)

@fieldwise_init
struct TextProjection(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Optional[String]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls[] += 1
        return Optional(String(value))

def main() raises:
    var mapped_calls = ArcPointer(0)
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid](TextProjection(mapped_calls)).get_or(""), "12")
    assert_equal(mapped_calls[], 2)
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid, type_of(text)](text).get_or(""), "12")
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[M=StringMonoid](text).get_or(""), "12")
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[OptionalFamily, StringMonoid, type_of(text)](text).get_or(""), "12")
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[J=OptionalFamily, M=StringMonoid](text).get_or(""), "12")
    assert_equal(pipeline(List[Int]([1])).fold_effect[OptionalFamily](10).run[type_of(sum_step)](sum_step).get_or(0), 11)
    assert_equal(pipeline(List[Int]([1])).fold_effect(10).run[OptionalFamily, type_of(sum_step)](sum_step).get_or(0), 11)
    assert_equal(pipeline(List[Int]([1, 2])).any_effect[OptionalFamily, type_of(even)](even).get_or(False), True)
    assert_equal(pipeline(List[Int]()).all_effect(even).get().value(), True)
    assert_equal(pipeline(List[Int]()).any_effect(even).get().value(), False)
    assert_equal(Bool(pipeline(List[Int]()).find_effect(even).get().value()), False)
    assert_equal(Bool(pipeline(List[Int]([1])).find_map_effect(project).get().value()), False)
    assert_equal(pipeline(List[Int]()).fold_effect(10).run(sum_step).get().value(), 10)
    assert_equal(pipeline(List[Int]()).fold_map_effect[StringMonoid](text).get().value(), "")
    assert_equal(pipeline(List[Int]([1,2,3])).find_map_effect(project).get().value().value(), "2")
    assert_equal(pipeline(List[Int]([1,2,3])).fold_effect(10).run(sum_step).get().value(), 16)
    assert_equal(pipeline(List[Int]([1,2,3])).fold_map_effect[StringMonoid](text).get().value(), "123")
    assert_equal(pipeline(Optional(2)).find_effect(even).get().value().value(), 2)
    var array: Array[Int, 3] = [1,2,3]
    assert_equal(pipeline(array^).fold_effect(0).run(sum_step).get().value(), 6)
    var deque = Deque[Int]()
    deque.append(1); deque.append(2)
    assert_equal(pipeline(deque^).fold_map_effect[StringMonoid](text).get().value(), "12")
    var cursor = CombinatorRestarting(1)
    _ = cursor.__next__()
    assert_equal(pipeline(cursor^).fold_effect(0).run(sum_step).get().value(), 5)

    var calls = ArcPointer(List[Int]())
    var pulls = 0
    def choose(value: Int) {calls} -> Optional[Bool]:
        calls[].append(value)
        return Optional(value == 2)
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,8)).any_effect(choose).get().value(), True)
    assert_equal(pulls, 2); assert_equal(calls[], List[Int]([1,2]))
    calls[].clear(); pulls = 0
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,8)).all_effect(choose).get().value(), False)
    assert_equal(pulls, 1); assert_equal(calls[], List[Int]([1]))
    calls[].clear(); pulls = 0
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,8)).find_effect(choose).get().value().value(), 2)
    assert_equal(pulls, 2); assert_equal(calls[], List[Int]([1,2]))
    calls[].clear(); pulls = 0
    def missing(var value: Int) {calls} -> Result[Optional[Int], String]:
        calls[].append(value)
        if value == 2: return Err(String("stored"))
        return Ok(Optional[Int]())
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,8)).find_map_effect(missing).get()._err().value, "stored")
    assert_equal(pulls, 2); assert_equal(calls[], List[Int]([1,2]))
    def absent(value: Int) -> Optional[Bool]: return None
    pulls = 0
    assert_equal(Bool(pipeline(Counted(Pointer(to=pulls),0,8)).find_effect(absent).get()), False)
    assert_equal(pulls, 1)
    def branches(value: Int) -> List[Bool]: return List[Bool]([False, True])
    assert_equal(pipeline(List[Int]([1,2])).any_effect(branches).get(), List[Bool]([False,True,True]))
    def alternatives(var value: Int) -> List[String]:
        return List[String](["a","A"]) if value == 1 else List[String](["b","B"])
    assert_equal(pipeline(List[Int]([1,2])).fold_map_effect[StringMonoid](alternatives).get(), List[String](["ab","aB","Ab","AB"]))
    def find_branch(var value: Int) -> List[Optional[Int]]:
        return List[Optional[Int]]([Optional[Int](),Optional(1)]) if value == 1 else List[Optional[Int]]([Optional(20)])
    var found = pipeline(List[Int]([1,2,3])).find_map_effect(find_branch).get()
    assert_equal(len(found), 2)
    assert_equal(found[0].value(), 20); assert_equal(found[1].value(), 1)
