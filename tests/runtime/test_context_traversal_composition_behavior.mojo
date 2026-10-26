"""Traversal composition retains source shape and preserves both failure layers."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, ListFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

def select(var value: Int) -> Optional[Optional[Int]]:
    return Optional(Optional(value) if value % 2 == 0 else Optional[Int]())
def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value,value+10]))
def action(var value: Int) -> Optional[String]: return Optional(String(value))

def main() raises:
    assert_equal(pipeline(List[Int]([1,2,3])).traverse_filter[OptionalFamily](select).get().value(), List[Int]([2]))
    assert_equal(pipeline(List[Int]()).traverse_filter[OptionalFamily](select).get().value(), List[Int]())
    assert_equal(pipeline(List[Int]([1,2])).flat_traverse[OptionalFamily](expand).get().value(), List[Int]([1,11,2,12]))
    var optionals = List[Optional[Optional[Int]]]([Optional(Optional(1)),Optional(Optional[Int]()),Optional(Optional(3))])
    assert_equal(pipeline(optionals^).sequence_filter[OptionalFamily]().get().value(), List[Int]([1,3]))
    var lists = List[Optional[List[Int]]]([Optional(List[Int]([1,2])),Optional(List[Int]([3]))])
    assert_equal(pipeline(lists^).flat_sequence[OptionalFamily]().get().value(), List[Int]([1,2,3]))
    assert_equal(Bool(pipeline(Optional(1)).traverse_filter[OptionalFamily](select).get().value()), False)
    assert_equal(pipeline(Optional(2)).traverse_filter[OptionalFamily](select).get().value().value(), 2)
    def nested(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value + 10))
    assert_equal(pipeline(Optional(1)).flat_traverse[OptionalFamily](nested).get().value().value(), 11)
    assert_equal(Bool(pipeline(List[Int]([1,2])).traverse_void[OptionalFamily](action).get()), True)
    assert_equal(Bool(pipeline(List[Optional[Int]]([Optional(1),Optional[Int]()])).sequence_void[OptionalFamily]().get()), False)
    assert_equal(Bool(pipeline(List[Optional[Int]]()).sequence_void[OptionalFamily]().get()), True)

    var calls = ArcPointer(List[Int]())
    def checked(var value: Int) {calls} -> Result[Optional[Int], String]:
        calls[].append(value)
        if value == 2: return Err(String("target"))
        return Ok(Optional(value))
    assert_equal(pipeline(List[Int]([1,2,3])).traverse_filter[ResultFamily[String]](checked).get()._err().value, "target")
    assert_equal(calls[], List[Int]([1,2]))
    calls[].clear()
    var source = pipeline(Result[Int,Int](Err(7))).traverse_void[ResultFamily[String]](checked).get()
    assert_equal(source._ok().value._err().value, 7)
    assert_equal(len(calls[]), 0)
    var target = pipeline(Result[Int,Int](Ok(2))).traverse_void[ResultFamily[String]](checked).get()
    assert_equal(target._err().value, "target")
    assert_equal(calls[], List[Int]([2]))
    var successful = pipeline(Result[Int,String](Ok(1))).traverse_void[OptionalFamily](action).get()
    comptime assert type_of(successful) == Optional[Result[NoneType,String]]
    assert_equal(successful.value().is_ok(), True)
    var sequenced = pipeline(Result[Optional[Int],String](Ok(Optional(1)))).sequence_void[OptionalFamily]().get()
    assert_equal(sequenced.value().is_ok(), True)
    var source_failure = pipeline(Result[Optional[Int],String](Err(String("source")))).sequence_void[OptionalFamily]().get()
    assert_equal(source_failure.value()._err().value, "source")
    def inner(var value: Int) -> Optional[Result[Int,String]]:
        if value == 2: return Optional(Result[Int,String](Err(String("inner"))))
        return Optional(Result[Int,String](Ok(value)))
    var inner_failure = pipeline(Result[Int,String](Ok(2))).flat_traverse[OptionalFamily](inner).get()
    assert_equal(inner_failure.value()._err().value, "inner")
    var outer_failure = pipeline(Result[Int,String](Err(String("outer")))).flat_traverse[OptionalFamily](inner).get()
    assert_equal(outer_failure.value()._err().value, "outer")

    def branches(var value: Int) -> List[Optional[Int]]: return List[Optional[Int]]([Optional[Int](),Optional(value)])
    var choices = pipeline(List[Int]([1,2])).traverse_filter[ListFamily](branches).get()
    assert_equal(len(choices), 4)
    assert_equal(choices[0], List[Int]()); assert_equal(choices[1], List[Int]([2]))
    assert_equal(choices[2], List[Int]([1])); assert_equal(choices[3], List[Int]([1,2]))
    var discarded = pipeline(List[Int]([1,2])).traverse_void[ListFamily](branches).get()
    assert_equal(len(discarded), 4)
    calls[].clear()
    comptime Validation = ValidationFamily[ListMonoid[String]]
    def validate(var value: Int) {calls} -> Result[Optional[Int],List[String]]:
        calls[].append(value)
        if value % 2 == 1: return Err(List[String]([String(value)]))
        return Ok(Optional(value))
    assert_equal(pipeline(List[Int]([1,2,3])).traverse_filter[Validation](validate).get()._err().value, List[String](["1","3"]))
    assert_equal(calls[], List[Int]([1,2,3]))
    calls[].clear()
    assert_equal(pipeline(List[Int]([1,2,3])).traverse_void[Validation](validate).get()._err().value, List[String](["1","3"]))
    assert_equal(calls[], List[Int]([1,2,3]))
