"""Reuse selected effectful chains in projected search and monoid reduction."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily, ListFamily, StringMonoid
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from algebra_support.box import Box, BoxMonad
from algebra_support.iterators import Counted
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false


def select(value: Int) -> Optional[Int]:
    return Optional(value * 10) if value == 2 else Optional[Int]()


def project(value: Int) -> Result[Optional[Int], String]:
    if value < 0: return Err(String("negative"))
    return Ok(select(value))


def text(value: Int) -> Result[String, String]:
    if value < 0: return Err(String("negative"))
    return Ok(String(value))


def check_native_families() raises:
    var selector = kleisli[OptionalFamily](select)
    assert_equal(pipeline(List[Int]([1, 2, 3])).find_map(selector).get().value(), 20)
    assert_false(pipeline(List[Int]([1, 3])).find_map(selector).get())
    assert_equal(selector.call(2).value(), 20)
    var projection = kleisli[ResultFamily[String]](project)
    assert_equal(pipeline(List[Int]([1, 2, 3])).find_map_effect(projection).raise_on_err().value(), 20)
    assert_equal(pipeline(List[Int]([1, -2, 3])).find_map_effect(projection).get()._err().value, "negative")
    assert_true(projection.call(2).is_ok())
    var transform = kleisli[ResultFamily[String]](text)
    assert_equal(pipeline(List[Int]([1, 2, 3])).fold_map_effect[StringMonoid](transform).raise_on_err(), "123")
    assert_equal(pipeline(List[Int]()).fold_map_effect[StringMonoid](transform).raise_on_err(), "")
    assert_equal(pipeline(List[Int]([1, -2, 3])).fold_map_effect[StringMonoid](transform).get()._err().value, "negative")
    assert_equal(pipeline(List[Int]([4, 5])).fold_map_effect[ResultFamily[String], StringMonoid](transform).raise_on_err(), "45")
    assert_equal(transform.call(6).raise_on_err(), "6")
    def alternatives(value: Int) -> List[String]: return [String(value), "x"]
    var branching = kleisli[ListFamily](alternatives)
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid](branching).get(), ["12", "1x", "x2", "xx"])
    def boxed(value: Int) -> Box[String]: return Box(String(value))
    var custom = kleisli[BoxMonad](boxed)
    assert_equal(pipeline(List[Int]([3, 4])).fold_map_effect[StringMonoid](custom).get().unwrap(), "34")


def check_stopping() raises:
    var pulls = 0
    var calls = ArcPointer(0)
    def observed(value: Int) {calls} -> Result[Optional[Int], String]:
        calls[] += 1
        return project(value)
    var chain = kleisli[ResultFamily[String]](observed)
    assert_equal(pipeline(Counted(Pointer(to=pulls), 0, 5)).find_map_effect(chain).raise_on_err().value(), 20)
    assert_equal(pulls, 2)
    assert_equal(calls[], 2)
    assert_equal(chain.call(2).raise_on_err().value(), 20)


def check_deferred() raises:
    var calls = ArcPointer(0)
    def later(value: Int) {calls} -> Reader[Int].Pure[String]:
        calls[] += 1
        return Reader[Int].pure(String(value))
    var chain = kleisli[Reader[Int]](later)
    var pending = pipeline(List[Int]([1, 2])).fold_map_effect[StringMonoid](chain).get()
    assert_equal(calls[], 0)
    assert_equal(run[Reader[Int]](pending^, 0), "12")
    assert_equal(calls[], 2)
    def find_later(value: Int) {calls} -> Reader[Int].Pure[Optional[Int]]:
        calls[] += 1
        return Reader[Int].pure(select(value))
    var selector = kleisli[Reader[Int]](find_later)
    var searching = pipeline(List[Int]([1, 2, 3])).find_map_effect(selector).get()
    assert_equal(calls[], 2)
    assert_equal(run[Reader[Int]](searching^, 0).value(), 20)
    assert_equal(calls[], 4)
    assert_equal(run[Reader[Int]](chain.call(3), 0), "3")


def fail(value: Int) raises Int -> Result[String, String]: raise value


def check_native_error() raises:
    var chain = kleisli[ResultFamily[String]](fail)
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[String]().fold_map_effect[StringMonoid](chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 7)


def check_origins(owner: List[Int], error_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(error_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def keep(value: View) -> Optional[View]: return Optional(value)
    var selector = kleisli[OptionalFamily](keep)
    var found = pipeline(List[View]([view])).find_map(selector).get()
    assert_true(Pointer(to=found.value()[0]) == Pointer(to=owner[0]))
    def project_view(value: View) -> Result[Optional[View], Failure]: return Ok(Optional(value))
    var projection = kleisli[ResultFamily[Failure]](project_view)
    var projected = pipeline(List[View]([view])).find_map_effect(projection).get()
    assert_true(Pointer(to=projected._ok().value.value()[1]) == Pointer(to=owner[1]))
    def reject(value: View) {failure} -> Result[String, Failure]: return Err(failure)
    var rejecting = kleisli[ResultFamily[Failure]](reject)
    var folded = pipeline(List[View]([view])).fold_map_effect[StringMonoid](rejecting).get()
    assert_true(Pointer(to=folded._err().value[1]) == Pointer(to=error_owner[1]))
    def fail_view(value: View) raises Failure {failure} -> Optional[String]: raise failure
    var raising = kleisli[OptionalFamily](fail_view)
    var matched = False
    try: _ = pipeline(List[View]([view])).fold_map_effect[StringMonoid](raising).get()
    except error: matched = Pointer(to=error[0]) == Pointer(to=error_owner[0])
    assert_true(matched)


def main() raises:
    check_origins(List[Int]([7, 11]), List[Int]([13, 17]))
    check_native_families()
    check_stopping()
    check_deferred()
    check_native_error()
