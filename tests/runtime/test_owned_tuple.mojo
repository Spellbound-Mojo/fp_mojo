"""Tuple attachment infers move-only values through single-call families."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline, pipeline_values
from fp.algebra import ResultFamily, OptionalFamily
from fp.effects import Reader, run
from std.testing import assert_equal


@fieldwise_init
struct Box(Movable):
    var value: Int


def attached[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](
    var source: Result[T, E], var value: U
) -> Result[Tuple[T, U], E]:
    return pipeline(source^).tuple_right(value^).get()


def main() raises:
    var selected = pipeline(Result[Box, String](Ok(Box(1)))).tuple_left(Box(7)).get()
    var left = selected^.get_or((Box(0), Box(0)))
    assert_equal(left[0].value, 7)
    assert_equal(left[1].value, 1)
    var generic = attached(Result[Box, String](Ok(Box(2))), Box(8))
    var right = generic^.get_or((Box(0), Box(0)))
    assert_equal(right[0].value, 2)
    assert_equal(right[1].value, 8)
    var legacy = pipeline(Result[Int, String](Ok(3))).tuple_right(Box(9)).get()
    assert_equal(legacy^.get_or((0, Box(0)))[1].value, 9)
    var explicit = pipeline[ResultFamily[String]](Result[Int, String](Ok(4))).tuple_left(Box(10)).get()
    assert_equal(explicit^.get_or((Box(0), 0))[0].value, 10)
    var optional = pipeline(Optional(5)).tuple_right(Box(11)).get()
    assert_equal(optional.value()[1].value, 11)
    var optional_legacy = pipeline(Optional(5)).tuple_left(Box(12)).get()
    assert_equal(optional_legacy.value()[0].value, 12)
    var optional_explicit = pipeline[OptionalFamily](Optional(5)).tuple_right(Box(13)).get()
    assert_equal(optional_explicit.value()[1].value, 13)
    var identity = pipeline(Box(6)).tuple_right(Box(14)).get()
    assert_equal(identity[0].value, 6)
    assert_equal(identity[1].value, 14)
    comptime R = Reader[Int]
    var pending = pipeline[R](R.pure(Box(7))).tuple_left(Box(15)).get()
    var deferred = run[R](pending^, 0)
    assert_equal(deferred[0].value, 15)
    assert_equal(deferred[1].value, 7)
    assert_equal(pipeline(List[Int]([1, 2])).tuple_left(3).get(), [(3, 1), (3, 2)])
    assert_equal(pipeline(List[Int]([1, 2])).tuple_right(3).get(), [(1, 3), (2, 3)])
    var dictionary = Dict[String, Int]()
    dictionary["key"] = 2
    var selected_dictionary = pipeline_values(dictionary^).raising[Int]().tuple_right(3)
    comptime assert type_of(selected_dictionary).E == Int
    assert_equal(selected_dictionary^.get()["key"], (2, 3))
    var failed = pipeline(Result[Int, String](Err(String("kept")))).tuple_left(Box(16)).get()
    assert_equal(failed^.swap().get_or(String()), "kept")
