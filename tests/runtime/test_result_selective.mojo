"""Selective recovery runs only the selected error continuation."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.callables import BorrowCallable, OnceUnary, MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def rs_value() -> Result[Int, String]: return Ok(7)
def rs_error(message: String) -> Result[Int, String]: return Err(message.copy())
def rs_retry(error: String) -> Bool: return error == "retry"
def rs_restore(var error: String) -> Int: return error.byte_length()
def rs_continue(var error: String) -> Result[Int, String]: return Ok(error.byte_length() + 10)
def rs_reject(var error: String) -> Result[Int, String]: return Err("new " + error)
def rs_text(var error: String) -> String: return error^
def rs_number(value: Int) -> String: return String(value)
def rs_message(var value: Result[Int, String]) -> String: return value^.fold_owned(rs_number, rs_text)
def rs_inspect(error: String) -> Result[Int, String]: return Ok(error.byte_length())
def rs_bad_inspector(error: String) -> Result[Int, String]: return Err(String("inspection failed"))


@fieldwise_init
struct RSFailure(Movable):
    var code: Int


def rs_raise_predicate(error: String) raises RSFailure -> Bool: raise RSFailure(11)
def rs_raise_recovery(var error: String) raises RSFailure -> Int: raise RSFailure(22)
def rs_raise_continuation(var error: String) raises RSFailure -> Result[Int, String]: raise RSFailure(33)
def rs_raise_inspector(error: String) raises RSFailure -> Result[Int, String]: raise RSFailure(44)
def rs_checked_predicate(error: String) raises RSFailure -> Bool: return rs_retry(error)


@fieldwise_init
struct RSPredicate(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke(self, ref value: String) raises Never capturing -> Bool: return rs_retry(value)


@fieldwise_init
struct RSRecovery(MutableUnary):
    comptime Arg = String
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var error: String) -> Int:
        self.calls += 1
        return error.byte_length() + self.calls


@fieldwise_init
struct RSContinuation(OnceUnary):
    comptime Arg = String
    comptime Out = Result[Int, String]
    var result: Int
    def call_once(deinit self, var error: String) -> Self.Out: return Ok(self.result)


def main() raises:
    assert_equal(rs_value().recover_if(rs_retry, rs_restore).raise_on_err(), 7)
    assert_equal(rs_error("retry").recover_if(rs_retry, rs_restore).raise_on_err(), 5)
    assert_equal(rs_message(rs_error("keep").recover_if(rs_retry, rs_restore)), "keep")
    assert_equal(rs_value().or_else_if(rs_retry, rs_continue).raise_on_err(), 7)
    assert_equal(rs_error("retry").or_else_if(rs_retry, rs_continue).raise_on_err(), 15)
    assert_equal(rs_message(rs_error("keep").or_else_if(rs_retry, rs_continue)), "keep")
    assert_equal(rs_message(rs_error("retry").or_else_if(rs_retry, rs_reject)), "new retry")
    assert_equal(rs_value().flat_tap_err(rs_inspect).raise_on_err(), 7)
    assert_equal(rs_message(rs_error("retry").flat_tap_err(rs_inspect)), "retry")
    assert_equal(rs_message(rs_error("retry").flat_tap_err(rs_bad_inspector)), "inspection failed")
    assert_equal(pipeline(rs_error("retry")).recover_if(rs_retry, rs_restore).get().raise_on_err(), 5)
    assert_equal(pipeline(rs_error("retry")).or_else_if(rs_retry, rs_continue).get().raise_on_err(), 15)
    assert_equal(rs_message(pipeline(rs_error("keep")).flat_tap_err(rs_inspect).get()), "keep")
    assert_equal(rs_error("retry").recover_if(RSPredicate(), RSRecovery(0)).raise_on_err(), 6)
    assert_equal(rs_error("retry").recover_if(rs_retry, RSRecovery(1)).raise_on_err(), 7)
    assert_equal(rs_error("retry").recover_if(RSPredicate(), rs_restore).raise_on_err(), 5)
    assert_equal(rs_error("retry").or_else_if(RSPredicate(), RSContinuation(20)).raise_on_err(), 20)
    assert_equal(rs_error("retry").or_else_if(rs_retry, RSContinuation(21)).raise_on_err(), 21)
    assert_equal(rs_error("retry").or_else_if(RSPredicate(), rs_continue).raise_on_err(), 15)
    var calls = ArcPointer(List[Int]())
    def rs_counted_predicate(error: String) {calls} -> Bool:
        calls[].append(1)
        return rs_retry(error)
    def rs_counted_recovery(var error: String) {calls} -> Int:
        calls[].append(2)
        return 99
    _ = rs_value().recover_if(rs_counted_predicate, rs_counted_recovery)
    assert_equal(calls[], List[Int]())
    _ = rs_error("keep").recover_if(rs_counted_predicate, rs_counted_recovery)
    assert_equal(calls[], [1])
    var eager = pipeline(rs_error("retry")).recover_if(rs_counted_predicate, rs_counted_recovery)
    assert_equal(calls[], [1, 1, 2])
    assert_equal(eager^.get().raise_on_err(), 99)
    var code = 0
    try: _ = rs_error("retry").recover_if(rs_raise_predicate, rs_restore)
    except error: code = error.code
    assert_equal(code, 11)
    try: _ = rs_error("retry").recover_if(rs_retry, rs_raise_recovery)
    except error: code = error.code
    assert_equal(code, 22)
    try: _ = rs_error("retry").recover_if(rs_checked_predicate, rs_raise_recovery)
    except error: code = error.code
    assert_equal(code, 22)
    try: _ = rs_error("retry").or_else_if(rs_retry, rs_raise_continuation)
    except error: code = error.code
    assert_equal(code, 33)
    try: _ = pipeline(rs_error("retry")).flat_tap_err(rs_raise_inspector)
    except error: code = error.code
    assert_equal(code, 44)
    try: _ = rs_error("retry").recover_if(RSPredicate(), rs_raise_recovery)
    except error: code = error.code
    assert_equal(code, 22)
    try: _ = rs_error("retry").or_else_if(RSPredicate(), rs_raise_continuation)
    except error: code = error.code
    assert_equal(code, 33)
    var skipped = False
    try:
        skipped = rs_error("keep").recover_if(rs_checked_predicate, rs_raise_recovery).is_err()
        skipped &= rs_value().recover_if(rs_raise_predicate, rs_raise_recovery).is_ok()
        skipped &= rs_value().flat_tap_err(rs_raise_inspector).is_ok()
    except error: code = -error.code
    assert_true(skipped)
    assert_equal(code, 33)
    print("selective Result recovery: branches, receivers and native errors")
