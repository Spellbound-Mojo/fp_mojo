"""Whole-value observation differs from family payload observation and projection."""
from fp.functions import pipeline, Pipeline
from fp.algebra import ListFamily, OptionalFamily, ValidationFamily, StringMonoid
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def length(value: String) -> Int: return value.byte_length()
def odd(value: Int) -> Bool: return value % 2 == 1
def observe(value: Int): pass
def observe_never(value: Int) raises Never: pass

def main() raises:
    var seen = List[Int]()
    def inspect(value: Int) {ref seen} -> String:
        seen.append(value)
        return String(value)
    var unchanged = pipeline(7).tap(inspect).get()
    assert_equal(unchanged, 7)
    assert_equal(seen, List[Int]([7]))
    var values = pipeline(List[Int]([3, 1, 2])).tap_each(inspect).get()
    assert_equal(values, List[Int]([3, 1, 2]))
    assert_equal(seen, List[Int]([7, 3, 1, 2]))
    var pairs = pipeline(List[Int]([4, 5])).pair_with(inspect).get()
    assert_equal(pairs[0][0], 4)
    assert_equal(pairs[0][1], "4")
    assert_equal(pairs[1][1], "5")
    assert_equal(seen, List[Int]([7, 3, 1, 2, 4, 5]))
    var stage = pipeline(List[Int]([1, 2, 3, 4])).filter_not(odd)
    comptime assert type_of(stage) == Pipeline[ListFamily, List[Int]]
    assert_equal(stage^.tap_each(observe).get(), List[Int]([2, 4]))
    assert_equal(pipeline(Optional(2)).filter_not(odd).get().value(), 2)
    assert_equal(Bool(pipeline(Optional(1)).filter_not(odd).get()), False)
    assert_equal(pipeline(Optional(String("mojo"))).pair_with(length).get().value()[1], 4)

    # Empty carriers skip payload callbacks, but whole-value tap still runs.
    var wholes = 0
    def inspect_empty(value: List[Int]) {mut wholes}: wholes += 1
    assert_equal(len(pipeline(List[Int]()).tap(inspect_empty).tap_each(inspect).pair_with(inspect).get()), 0)
    assert_equal(wholes, 1)
    assert_equal(Bool(pipeline(Optional[Int]()).tap_each(inspect).filter_not(odd).get()), False)
    assert_equal(len(seen), 6)

    var outcomes = 0
    def inspect_result(value: Result[Int, String]) {mut outcomes}:
        if value.is_err(): outcomes += 1
    var failed = pipeline(Result[Int, String](Err(String("stored")))).tap(inspect_result).tap_each(inspect).pair_with(inspect).get()
    assert_equal(failed._err().value, "stored")
    assert_equal(outcomes, 1)
    assert_equal(len(seen), 6)
    var success = pipeline(Result[Int, String](Ok(8))).tap_each(observe_never).pair_with(inspect).get()
    assert_equal(success._ok().value[0], 8)
    assert_equal(success._ok().value[1], "8")
    comptime Validation = ValidationFamily[StringMonoid]
    var validation = pipeline[Validation](Result[Int, String](Err(String("validation")))).tap_each(inspect).pair_with(inspect).get()
    assert_equal(validation._err().value, "validation")
    assert_equal(len(seen), 7)

