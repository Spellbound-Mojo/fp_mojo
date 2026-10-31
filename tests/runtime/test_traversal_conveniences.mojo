"""Traversal policies share effects, short-circuiting and source traversal."""
from fp.functions import piped
from fp.combinators import traverse_void, traverse_tap
from fp.iteration import iterated
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily, ListFamily
from fp.effects import Reader, State, run, action
from fp.data import Result, Ok, Err
from fp.callables import as_unary
from std.testing import assert_equal, assert_true, assert_false
from std.memory import ArcPointer
from std.collections import Array, Deque, LinkedList
from algebra_support.iterators import Counted
from algebra_support.arrows import Produce, ReadStep
from test_algebra_third_party import Two, TwoFamily, Cell, CellFamily


def tv_values() -> List[Int]: return [1, 2, 3]
def tv_success(value: Int) -> Result[Int, String]: return Result[Int, String](Ok(value * 10))
def tv_failure(value: Int) -> Result[Int, String]:
    if value == 2: return Result[Int, String](Err(String("stop")))
    return tv_success(value)
def tv_optional(value: Int) -> Optional[Int]: return Optional(value * 10)
def tv_choices(value: Int) -> List[Int]: return [value, value + 10]
def tv_cell(value: Int) -> Cell[Int]: return Cell(value * 10)
def tv_error(error: String) -> String: return error
def tv_none(value: NoneType) -> String: return "success"


@fieldwise_init
struct TVFailure(Movable):
    var code: Int


def tv_raise(value: Int) raises TVFailure -> Optional[Int]:
    raise TVFailure(value)


def main() raises:
    var done = piped(tv_values()).traverse_void[ResultFamily[String]](tv_success).get()
    assert_true(done.is_ok())
    _ = done^.raise_on_err()
    var failed = piped(tv_values()).traverse_void[ResultFamily[String]](tv_failure).get()
    assert_equal(failed^.fold_owned(tv_none, tv_error), "stop")
    var original = piped(tv_values()).traverse_tap[ResultFamily[String]](tv_success).get()
    assert_equal(original^.raise_on_err(), [1, 2, 3])
    assert_true(piped(tv_values()).traverse_tap[ResultFamily[String]](tv_failure).get().is_err())
    var option = piped(Optional(7)).traverse_tap[OptionalFamily](tv_optional).get()
    assert_equal(option.take().value(), 7)
    var absent = piped(Optional[Int]()).traverse_tap[OptionalFamily](tv_optional).get()
    assert_false(absent.take())
    var empty = piped(List[Int]()).traverse_void[OptionalFamily](tv_optional).get()
    assert_true(empty)
    var choices = piped(tv_values()).traverse_tap[ListFamily](tv_choices).get()
    assert_equal(len(choices), 8)
    for choice in choices: assert_equal(choice, [1, 2, 3])
    var discarded_choices = piped(tv_values()).traverse_void[ListFamily](tv_choices).get()
    assert_equal(len(discarded_choices), 8)
    var source_error = piped(Result[Int, String](Err(String("source")))).traverse_tap[OptionalFamily](tv_optional).get()
    assert_true(source_error.take().is_err())
    var source_ok = piped(Result[Int, String](Ok(7))).traverse_tap[OptionalFamily](tv_optional).get()
    assert_equal(source_ok.take().raise_on_err(), 7)
    var source_void = piped(Result[Int, String](Ok(7))).traverse_void[OptionalFamily](tv_optional).get()
    comptime assert type_of(source_void) == Optional[Result[NoneType, String]]
    assert_true(source_void.take().is_ok())
    var source_calls = ArcPointer(0)
    def tv_counted(value: Int) {source_calls} -> Result[Int, String]:
        source_calls[] += 1
        return tv_failure(value)
    var preserved_error = piped(Result[Int, String](Err(String("source")))).traverse_void[ResultFamily[String]](tv_counted).get()
    var inner_error = preserved_error^.raise_on_err()
    assert_equal(inner_error^.fold_owned(tv_none, tv_error), "source")
    assert_equal(source_calls[], 0)
    var callback_error = piped(Result[Int, String](Ok(2))).traverse_void[ResultFamily[String]](tv_counted).get()
    assert_true(callback_error.is_err())
    assert_equal(source_calls[], 1)
    var custom = piped(Two(2, 4)).traverse_tap[CellFamily, TwoFamily](tv_cell).get().take()
    assert_equal(custom.first, 2)
    assert_equal(custom.second, 4)
    var pulls = 0
    var stopped = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse_void[ResultFamily[String]](tv_failure)
    assert_true(stopped.is_err())
    assert_equal(pulls, 2)
    pulls = 0
    var retained = iterated(Counted(Pointer(to=pulls), 0, 3)).traverse_tap[OptionalFamily](tv_optional)
    assert_equal(retained.take(), [1, 2, 3])
    assert_equal(pulls, 4)
    var free = traverse_tap[OptionalFamily](tv_values(), tv_optional)
    assert_equal(free.take(), [1, 2, 3])
    _ = traverse_void[OptionalFamily](tv_values(), as_unary(tv_optional))
    var raised = 0
    try: _ = piped(tv_values()).traverse_tap[OptionalFamily](tv_raise)
    except error: raised = error.code
    assert_equal(raised, 1)
    try: _ = iterated(tv_values()).traverse_void[OptionalFamily](tv_raise)
    except error: raised = error.code + 10
    assert_equal(raised, 11)
    var array: Array[Int, 2] = [1, 2]
    assert_true(piped(array^).traverse_void[OptionalFamily](tv_optional).get())
    var deque = Deque[Int]()
    deque.append(1)
    assert_true(piped(deque^).traverse_void[OptionalFamily](tv_optional).get())
    var linked = LinkedList[Int]()
    linked.append(1)
    assert_true(piped(linked^).traverse_void[OptionalFamily](tv_optional).get())
    var tap_calls = ArcPointer(0)
    def tv_reader(value: Int) {tap_calls} -> type_of(action[Reader[Int], Int](ReadStep(0))):
        tap_calls[] += 1
        return action[Reader[Int], Int](ReadStep(value))
    var deferred_tap = piped(tv_values()).traverse_tap[Reader[Int]](tv_reader).get()
    assert_equal(tap_calls[], 0)
    var tap_environment = 10
    assert_equal(run[Reader[Int]](deferred_tap^, tap_environment), [1, 2, 3])
    assert_equal(tap_calls[], 3)
    for count in [0, 3]:
        pulls = 0
        var calls = ArcPointer(0)
        var reader = iterated(Counted(Pointer(to=pulls), 0, count)).traverse_void[Reader[Int]](Produce[False](calls))
        assert_equal(pulls, 0)
        assert_equal(calls[], 0)
        var environment = 10
        _ = run[Reader[Int]](reader^, environment)
        assert_equal(pulls, count + 1)
        assert_equal(calls[], count)
        pulls = 0
        calls[] = 0
        var state = traverse_void[State[Int]](Counted(Pointer(to=pulls), 0, count), Produce[True](calls))
        assert_equal(pulls, 0)
        var output = run[State[Int]](state^, 10)
        assert_equal(output[1], 10 if count == 0 else 16)
        assert_equal(pulls, count + 1)
        assert_equal(calls[], count)
    print("traversal conveniences: retention, short circuit and deferred effects")
