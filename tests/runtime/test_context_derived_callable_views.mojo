"""Reusable effectful chains compose with filtering, flattening and discard."""
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def select(value: Int) -> Result[Optional[Int], String]:
    if value < 0: return Err(String("negative"))
    return Ok(Optional(value * 10) if value % 2 == 0 else Optional[Int]())


def expand(value: Int) -> Result[List[Int], String]:
    if value < 0: return Err(String("negative"))
    return Ok(List[Int]([value, value + 10]))


def check_results() raises:
    var selector = kleisli[ResultFamily[String]](select)
    assert_equal(pipeline(List[Int]([1, 2, 3, 4])).traverse_filter(selector).raise_on_err(), [20, 40])
    assert_true(pipeline(List[Int]([1, -2, 3])).traverse_filter(selector).get().is_err())
    assert_equal(selector.call(6).raise_on_err().value(), 60)
    var expander = kleisli[ResultFamily[String]](expand)
    assert_equal(pipeline(List[Int]([1, 2])).flat_traverse(expander).raise_on_err(), [1, 11, 2, 12])
    assert_true(pipeline(List[Int]([1, -2, 3])).flat_traverse(expander).get().is_err())
    assert_true(pipeline(List[Int]([1, 2])).traverse_void(expander).get().is_ok())
    assert_equal(pipeline(List[Int]([1, -2, 3])).traverse_void(expander).get()._err().value, "negative")
    var absent = pipeline(Result[Int, String](Err(String("source")))).traverse_void(expander).get()
    comptime assert type_of(absent) == Result[Result[NoneType, String], String]
    assert_equal(absent._ok().value._err().value, "source")
    assert_equal(expander.call(3).raise_on_err(), [3, 13])


def check_deferred() raises:
    var calls = ArcPointer(0)
    def select_later(value: Int) {calls} -> Reader[Int].Pure[Optional[Int]]:
        calls[] += 1
        return Reader[Int].pure(Optional(value) if value % 2 == 0 else Optional[Int]())
    var selector = kleisli[Reader[Int]](select_later)
    var pending = pipeline(List[Int]([1, 2, 3])).traverse_filter(selector).get()
    assert_equal(calls[], 0)
    assert_equal(run[Reader[Int]](pending^, 0), [2])
    assert_equal(calls[], 3)
    var discarded = pipeline(range(3)).traverse_void(selector).get()
    assert_equal(calls[], 3)
    _ = run[Reader[Int]](discarded^, 0)
    assert_equal(calls[], 6)
    def expand_later(value: Int) {calls} -> Reader[Int].Pure[List[Int]]:
        calls[] += 1
        return Reader[Int].pure(List[Int]([value, value + 10]))
    var expander = kleisli[Reader[Int]](expand_later)
    var flattened = pipeline(List[Int]([3, 4])).flat_traverse(expander).get()
    assert_equal(calls[], 6)
    assert_equal(run[Reader[Int]](flattened^, 0), [3, 13, 4, 14])
    assert_equal(calls[], 8)
    assert_equal(run[Reader[Int]](expander.call(5), 0), [5, 15])


def fail(value: Int) raises Int -> Result[List[Int], String]: raise value


def check_native_error() raises:
    var chain = kleisli[ResultFamily[String]](fail)
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[String]().flat_traverse(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 7)
    try: _ = pipeline(List[Int]([11])).raising[String]().traverse_void(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 11)


def check_origins(owner: List[Int], error_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(error_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def keep(value: View) -> Result[Optional[View], Failure]: return Ok(Optional(value))
    var selector = kleisli[ResultFamily[Failure]](keep)
    var selected = pipeline(List[View]([view])).traverse_filter(selector).get()
    assert_true(Pointer(to=selected._ok().value[0][0]) == Pointer(to=owner[0]))
    def expand_view(value: View) -> Result[List[View], Failure]: return Ok(List[View]([value]))
    var expander = kleisli[ResultFamily[Failure]](expand_view)
    var expanded = pipeline(List[View]([view])).flat_traverse(expander).get()
    assert_true(Pointer(to=expanded._ok().value[0][1]) == Pointer(to=owner[1]))
    def reject(value: View) {failure} -> Result[Int, Failure]: return Err(failure)
    var rejecting = kleisli[ResultFamily[Failure]](reject)
    var discarded = pipeline(List[View]([view])).traverse_void(rejecting).get()
    assert_true(Pointer(to=discarded._err().value[1]) == Pointer(to=error_owner[1]))


def main() raises:
    check_origins(List[Int]([7, 11]), List[Int]([13, 17]))
    check_results()
    check_deferred()
    check_native_error()
