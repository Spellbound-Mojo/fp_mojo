"""Reusable handlers preserve selected error layers and Result terminals."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily, ListFamily
from fp.effects import Reader, ResultT, run
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true
from std.memory import ArcPointer

def fallback(var reason: String) -> Int: return reason.byte_length()
def retry(var reason: String) -> Result[Int, String]: return Ok(reason.byte_length())
def change(var reason: String) -> Result[Int, Int]: return Err(reason.byte_length())

def check_basics() raises:
    var restore = kleisli[IdentityFamily](fallback)
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).recover(restore).raise_on_err(), 7)
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).value_or(restore), 3)
    assert_equal(Result[Int, String](Err(String("direct"))).value_or(restore), 6)
    assert_equal(Result[Int, String](Err(String("direct"))).recover(restore).raise_on_err(), 6)
    assert_equal(restore.call(String("again")), 5)
    var repeat = kleisli[ResultFamily[String]](retry)
    assert_equal(pipeline(Result[Int, String](Err(String("retry")))).or_else(repeat).raise_on_err(), 5)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("raw")))).or_else(repeat).raise_on_err(), 3)
    assert_equal(Result[Int, String](Err(String("direct"))).or_else(repeat).raise_on_err(), 6)
    var replace = kleisli[ResultFamily[Int]](change)
    assert_equal(pipeline(Result[Int, String](Err(String("changed")))).or_else(replace).get()._err().value, 7)
    comptime Layer = ResultT[Reader[Int], String]
    var pending = pipeline[Layer](Layer.fail[Int](String("later"))).recover(restore).get()
    assert_equal(run[Reader[Int]](pending^, 0)._ok().value, 5)
    def retry_later(var reason: String) -> Layer.Pure[Int]: return Layer.pure(reason.byte_length())
    var deferred = kleisli[Layer](retry_later)
    var recovered = pipeline[Layer](Layer.fail[Int](String("deferred"))).or_else(deferred).get()
    assert_equal(run[Reader[Int]](recovered^, 0)._ok().value, 8)


def check_branches() raises:
    var calls = ArcPointer(0)
    def restore(var reason: String) {calls} -> Int:
        calls[] += 1
        return reason.byte_length()
    var handler = kleisli[IdentityFamily](restore)
    assert_equal(Result[Int, String](Ok(7)).value_or(handler), 7)
    assert_equal(Result[Int, String](Ok(8)).recover(handler).raise_on_err(), 8)
    assert_equal(pipeline(Result[Int, String](Ok(9))).recover(handler).raise_on_err(), 9)
    assert_equal(pipeline(Result[Int, String](Ok(10))).value_or(handler), 10)
    assert_equal(calls[], 0)
    comptime Many = ResultT[ListFamily, String]
    var source: List[Result[Int, String]] = [Ok(3), Err(String("a")), Err(String("four"))]
    var recovered = pipeline[Many](source^).recover(handler)
    comptime assert type_of(recovered).I == Many
    var values = recovered^.get()
    assert_equal(values[0]._ok().value, 3)
    assert_equal(values[1]._ok().value, 1)
    assert_equal(values[2]._ok().value, 4)
    assert_equal(calls[], 2)
    comptime Nested = ResultT[ResultFamily[String], String]
    var outer = Result[Result[Int, String], String](Err(String("outer")))
    var untouched = pipeline[Nested](outer^).recover(handler).get()
    assert_equal(untouched._err().value, "outer")
    assert_equal(calls[], 2)
    def retry_counted(var reason: String) {calls} -> Result[Int, Int]:
        calls[] += 1
        return Err(reason.byte_length())
    var retry = kleisli[ResultFamily[Int]](retry_counted)
    var kept = pipeline(Result[Int, String](Ok(11))).or_else(retry)
    comptime assert type_of(kept).I == ResultFamily[Int]
    assert_equal(kept^.get()._ok().value, 11)
    assert_equal(Result[Int, String](Ok(12)).or_else(retry)._ok().value, 12)
    assert_equal(calls[], 2)
    assert_equal(pipeline(Result[Int, String](Err(String("three")))).or_else(retry).get()._err().value, 5)
    assert_equal(calls[], 3)
    assert_equal(handler.call(String("reuse")), 5)


def fail(var reason: String) raises Int -> Int: raise reason.byte_length()
def fail_effect(var reason: String) raises Int -> Result[Int, String]: raise reason.byte_length()


def check_native_errors() raises:
    var handler = kleisli[IdentityFamily](fail)
    var code = 0
    try: _ = pipeline(Result[Int, String](Err(String("test")))).raising[String]().recover(handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 4)
    try: _ = Result[Int, String](Err(String("value"))).value_or(handler)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 5)
    var retry = kleisli[ResultFamily[String]](fail_effect)
    try: _ = pipeline(Result[Int, String](Err(String("retry!")))).raising[String]().or_else(retry).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 6)


def check_origins(owner: List[Int], failure_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(failure_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def restore(var error: Int) {view} -> View: return view
    var handler = kleisli[IdentityFamily](restore)
    var direct = Result[View, Int](Err(1)).value_or(handler)
    assert_true(Pointer(to=direct[0]) == Pointer(to=owner[0]))
    var recovered = pipeline(Result[View, Int](Err(2))).recover(handler).get()
    assert_true(Pointer(to=recovered._ok().value[1]) == Pointer(to=owner[1]))
    def reject(var error: Int) {failure} -> Result[View, Failure]: return Err(failure)
    var retry = kleisli[ResultFamily[Failure]](reject)
    var replaced = pipeline(Result[View, Int](Err(3))).or_else(retry).get()
    assert_true(Pointer(to=replaced._err().value[1]) == Pointer(to=failure_owner[1]))


def main() raises:
    check_basics()
    check_branches()
    check_native_errors()
    check_origins(List[Int]([7, 11]), List[Int]([13, 17]))
