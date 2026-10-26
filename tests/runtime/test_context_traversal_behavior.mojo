"""Borrowing traversal retains source shape and the target's sequencing policy."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, ListFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

def present(value: Int) -> Optional[String]: return Optional(String(value))
def even(value: Int) -> Optional[Bool]: return Optional(value % 2 == 0)
def count(var values: List[Int]) -> Int: return len(values)

def main() raises:
    assert_equal(pipeline(5).traverse_tap[OptionalFamily](present).get().value(), 5)
    var kept = pipeline(List[Int]([1, 2, 3])).traverse_tap[OptionalFamily](present).get()
    assert_equal(kept.value(), List[Int]([1, 2, 3]))
    assert_equal(pipeline(List[Int]([1, 2, 3, 4])).filter_effect[OptionalFamily](even).map(count).get().value(), 2)
    assert_equal(pipeline(Optional(2)).filter_effect[OptionalFamily](even).get().value().value(), 2)
    assert_equal(Bool(pipeline(Optional(1)).filter_effect[OptionalFamily](even).get().value()), False)
    assert_equal(Bool(pipeline(Optional[Int]()).filter_effect[OptionalFamily](even).get().value()), False)
    assert_equal(pipeline(List[Int]()).traverse_tap[OptionalFamily](present).get().value(), List[Int]())
    assert_equal(pipeline(List[Int]()).filter_effect[OptionalFamily](even).get().value(), List[Int]())
    var source_error = pipeline(Result[Int, String](Err(String("source")))).traverse_tap[OptionalFamily](present).get()
    assert_equal(source_error.value()._err().value, "source")
    var source_ok = pipeline(Result[Int, String](Ok(7))).traverse_tap[OptionalFamily](present).get()
    assert_equal(source_ok.value()._ok().value, 7)

    var calls = ArcPointer(List[Int]())
    def checked(value: Int) {calls} -> Result[Bool, String]:
        calls[].append(value)
        if value == 3: return Err(String("target"))
        return Ok(value % 2 == 0)
    var failed = pipeline(List[Int]([1, 2, 3, 4])).filter_effect[ResultFamily[String]](checked).get()
    assert_equal(failed._err().value, "target")
    assert_equal(calls[], List[Int]([1, 2, 3]))
    calls[].clear()
    var stopped = pipeline(List[Int]([1, 2, 3, 4])).traverse_tap[ResultFamily[String]](checked).get()
    assert_equal(stopped._err().value, "target")
    assert_equal(calls[], List[Int]([1, 2, 3]))
    calls[].clear()
    def absent(value: Int) {calls} -> Optional[Bool]:
        calls[].append(value)
        if value == 2: return None
        return Optional(True)
    assert_equal(Bool(pipeline(List[Int]([1, 2, 3])).filter_effect[OptionalFamily](absent).get()), False)
    assert_equal(calls[], List[Int]([1, 2]))

    def branches(value: Int) -> List[Bool]: return List[Bool]([False, True])
    var choices = pipeline(List[Int]([1, 2])).filter_effect[ListFamily](branches).get()
    assert_equal(len(choices), 4)
    assert_equal(choices[0], List[Int]())
    assert_equal(choices[1], List[Int]([2]))
    assert_equal(choices[2], List[Int]([1]))
    assert_equal(choices[3], List[Int]([1, 2]))
    var repeated = pipeline(List[Int]([1, 2])).traverse_tap[ListFamily](branches).get()
    assert_equal(len(repeated), 4)
    for values in repeated: assert_equal(values, List[Int]([1, 2]))

    calls[].clear()
    comptime Validation = ValidationFamily[ListMonoid[String]]
    def validate(value: Int) {calls} -> Result[Bool, List[String]]:
        calls[].append(value)
        if value % 2 == 1: return Err(List[String]([String(value)]))
        return Ok(True)
    var errors = pipeline(List[Int]([1, 2, 3, 4])).filter_effect[Validation](validate).get()
    assert_equal(errors._err().value, List[String](["1", "3"]))
    assert_equal(calls[], List[Int]([1, 2, 3, 4]))
    calls[].clear()
    var more_errors = pipeline(List[Int]([1, 2, 3, 4])).traverse_tap[Validation](validate).get()
    assert_equal(more_errors._err().value, List[String](["1", "3"]))
    assert_equal(calls[], List[Int]([1, 2, 3, 4]))

