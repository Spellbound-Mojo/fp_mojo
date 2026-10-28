"""Reusable success/error handlers compose without wrapper closures."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily, ListFamily, ValidationFamily, StringMonoid, ListMonoid
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from std.testing import assert_equal, assert_true
from std.memory import ArcPointer
from context_error_mapping_support import MappingOnly


def show(value: Int) -> String: return String(value)
def size(var reason: String) -> Int: return reason.byte_length()
def explain(var reason: String) -> String: return "failed:" + reason

def accept(value: Int) -> Result[String, Int]: return Ok(String(value))
def retry(var reason: String) -> Result[String, Int]: return Err(reason.byte_length())


def check_basics() raises:
    var display = kleisli[IdentityFamily](show)
    var code = kleisli[IdentityFamily](size)
    var report = kleisli[IdentityFamily](explain)
    assert_equal(Result[Int, String](Err(String("bad"))).map_err(code)._err().value, 3)
    var remapped = pipeline(Result[Int, String](Err(String("bad")))).map_err(code)
    comptime assert type_of(remapped).I == ResultFamily[Int]
    assert_equal(remapped^.get()._err().value, 3)
    assert_equal(Result[Int, String](Ok(7)).map_both(display, code)._ok().value, "7")
    assert_equal(Result[Int, String](Err(String("bad"))).map_both(show, code)._err().value, 3)
    assert_equal(Result[Int, String](Ok(8)).map_both(display, size)._ok().value, "8")
    assert_equal(pipeline(Result[Int, String](Ok(9))).map_both(display, code).get()._ok().value, "9")
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("raw")))).map_both(display, code).get()._err().value, 3)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Err(String("raw")))).map_err(code).get()._err().value, 3)
    assert_equal(Result[Int, String](Err(String("bad"))).redeem(display, report).raise_on_err(), "failed:bad")
    assert_equal(Result[Int, String](Ok(10)).redeem(display, explain).raise_on_err(), "10")
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).redeem(show, report).raise_on_err(), "failed:bad")
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Ok(11))).redeem(display, report).raise_on_err(), "11")
    var success = kleisli[ResultFamily[Int]](accept)
    var failure = kleisli[ResultFamily[Int]](retry)
    assert_equal(Result[Int, String](Ok(12)).redeem_with(success, failure)._ok().value, "12")
    assert_equal(Result[Int, String](Err(String("bad"))).redeem_with(accept, failure)._err().value, 3)
    assert_equal(Result[Int, String](Ok(13)).redeem_with(success, retry)._ok().value, "13")
    var replacement = pipeline(Result[Int, String](Err(String("changed")))).redeem_with(success, failure)
    comptime assert type_of(replacement).I == ResultFamily[Int]
    assert_equal(replacement^.get()._err().value, 7)
    assert_equal(pipeline[IdentityFamily](Result[Int, String](Ok(14))).redeem_with(success, failure).raise_on_err(), "14")
    assert_equal(code.call(String("reuse")), 5)
    assert_equal(display.call(15), "15")


def check_selection() raises:
    var calls = ArcPointer(0)
    def reject(value: Int) -> Result[String, Int]: return Err(value)
    def recover(var reason: String) {calls} -> Result[String, Int]:
        calls[] += 1
        return Ok(reason^)
    var success = kleisli[ResultFamily[Int]](reject)
    var failure = kleisli[ResultFamily[Int]](recover)
    assert_equal(pipeline(Result[Int, String](Ok(17))).redeem_with(success, failure).get()._err().value, 17)
    assert_equal(Result[Int, String](Ok(19)).redeem_with(success, failure)._err().value, 19)
    assert_equal(calls[], 0)
    assert_equal(pipeline(Result[Int, String](Err(String("selected")))).redeem_with(success, failure).raise_on_err(), "selected")
    assert_equal(calls[], 1)


def check_families() raises:
    var display = kleisli[IdentityFamily](show)
    var code = kleisli[IdentityFamily](size)
    var report = kleisli[IdentityFamily](explain)
    comptime Mapping = MappingOnly[String]
    var mapped = pipeline[Mapping](Result[Int, String](Err(String("custom")))).map_both(display, code)
    comptime assert type_of(mapped).I == MappingOnly[Int]
    assert_equal(mapped^.get()._err().value, 6)
    comptime Validation = ValidationFamily[StringMonoid]
    var retained = pipeline[Validation](Validation.fail[Int](String("bad"))).map_err(report)
    comptime assert type_of(retained).I == Validation
    assert_equal(retained^.get()._err().value, "failed:bad")
    def list_error(var error: String) -> List[String]: return [error^]
    var list_errors = kleisli[IdentityFamily](list_error)
    comptime Lists = ValidationFamily[ListMonoid[String]]
    var changed = pipeline[Validation](Validation.fail[Int](String("bad"))).map_err[Target=Lists](list_errors)
    comptime assert type_of(changed).I == Lists
    assert_equal(changed^.get()._err().value, List[String](["bad"]))
    comptime Many = ResultT[ListFamily, String]
    var source: List[Result[Int, String]] = [Ok(2), Err(String("bad")), Ok(3)]
    var messages = pipeline[Many](source^).redeem(display, report).get()
    assert_equal(messages[0]._ok().value, "2")
    assert_equal(messages[1]._ok().value, "failed:bad")
    assert_equal(messages[2]._ok().value, "3")
    comptime Later = ResultT[Reader[Int], String]
    var deferred = pipeline[Later](Later.fail[Int](String("later"))).redeem(display, report).get()
    assert_equal(run[Reader[Int]](deferred^, 0)._ok().value, "failed:later")
    def defer_ok(value: Int) -> Later.Pure[String]: return Later.pure(String(value))
    def defer_err(var reason: String) -> Later.Pure[String]: return Later.pure(reason^)
    var on_ok = kleisli[Later](defer_ok)
    var on_err = kleisli[Later](defer_err)
    var pending = pipeline[Later](Later.fail[Int](String("selected"))).redeem_with(on_ok, on_err).get()
    assert_equal(run[Reader[Int]](pending^, 0)._ok().value, "selected")


def check_errors() raises:
    def fail(var reason: String) raises Int -> Int: raise 23
    var handler = kleisli[IdentityFamily](fail)
    var code = 0
    try: _ = pipeline(Result[Int, String](Err(String("bad")))).raising[String]().map_err(handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 23)
    def double(value: Int) -> Int: return value * 2
    var success = kleisli[IdentityFamily](double)
    try: _ = Result[Int, String](Err(String("bad"))).redeem(success, handler)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 23)
    var retained: Int
    try: retained = pipeline(Result[Int, String](Ok(13))).redeem(success, handler).get()._ok().value
    except _: raise Error("successful branch invoked the failing handler")
    assert_equal(retained, 26)


def check_origins(owner: List[Int], errors: List[Int]) raises:
    var view = Span(owner)
    var reason = Span(errors)
    comptime V = type_of(view)
    comptime E = type_of(reason)
    def success(value: Int) {view} -> V: return view
    def failure(var text: String) {reason} -> E: return reason
    var on_ok = kleisli[IdentityFamily](success)
    var on_err = kleisli[IdentityFamily](failure)
    var mapped = pipeline(Result[Int, String](Err(String("bad")))).map_both(on_ok, on_err).get()
    assert_true(Pointer(to=mapped._err().value[0]) == Pointer(to=errors[0]))
    var kept = Result[Int, String](Ok(1)).map_both(on_ok, on_err)
    assert_true(Pointer(to=kept._ok().value[0]) == Pointer(to=owner[0]))


def check_composed() raises:
    def double(value: Int) -> Int: return value * 2
    def punctuate(var text: String) -> String: return text + "!"
    var display = kleisli[IdentityFamily](show).map(punctuate)
    var code = kleisli[IdentityFamily](size).map(double)
    var report = kleisli[IdentityFamily](explain).map(punctuate)
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).map_err(code).get()._err().value, 6)
    assert_equal(Result[Int, String](Ok(7)).map_both(display, code)._ok().value, "7!")
    var stored_code = 0
    try: _ = pipeline(Result[Int, String](Err(String("bad")))).map_both(display, code).raise_on_err()
    except error:
        comptime assert type_of(error) == Int
        stored_code = error
    assert_equal(stored_code, 6)
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).redeem(display, report).raise_on_err(), "failed:bad!")
    var success = kleisli[ResultFamily[Int]](accept).map(punctuate)
    var failure = kleisli[ResultFamily[Int]](retry).map(punctuate)
    assert_equal(pipeline(Result[Int, String](Ok(11))).redeem_with(success, failure).raise_on_err(), "11!")
    assert_equal(Result[Int, String](Ok(13)).redeem_with(success, failure).raise_on_err(), "13!")


def main() raises:
    check_basics()
    check_composed()
    check_selection()
    check_families()
    check_errors()
    check_origins(List[Int]([29, 31]), List[Int]([37, 41]))
