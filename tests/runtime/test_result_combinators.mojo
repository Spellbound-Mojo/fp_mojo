"""Result composition: branch selection, native errors and callback ownership."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.callables import BorrowCallable, BorrowOnceCallable, OnceThunk, MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def rc_ok(value: Int = 3) -> Result[Int, String]: return Ok(value)
def rc_err() -> Result[Int, String]: return Err(String("original"))
def rc_positive(value: Int) -> Bool: return value > 0
def rc_problem(value: Int) -> String: return "rejected " + String(value)
def rc_project(value: Int) -> Result[String, String]: return Ok(String(value))
def rc_next() -> Result[String, String]: return Ok(String("next"))
def rc_bad_next() -> Result[String, String]: return Err(String("next error"))
def rc_recover(var error: String) -> Int: return error.byte_length()
def rc_error(var error: String) -> Int: return error.byte_length()
def rc_retry(error: Int) -> Result[Int, Int]: return Ok(error + 10)
def rc_error_text(error: String) -> String: return error.copy()
def rc_value_text(value: Int) -> String: return String(value)
def rc_failure(var result: Result[Int, String]) -> String:
    return result^.fold_owned(rc_value_text, rc_error_text)


@fieldwise_init
struct RCNativeFailure(Movable):
    var code: Int


def rc_raise_projection(value: Int) raises RCNativeFailure -> Result[String, String]:
    raise RCNativeFailure(value)
def rc_raise_factory() raises RCNativeFailure -> Result[String, String]:
    raise RCNativeFailure(11)
def rc_raise_predicate(value: Int) raises RCNativeFailure -> Bool:
    raise RCNativeFailure(value + 20)
def rc_raise_error(value: Int) raises RCNativeFailure -> String:
    raise RCNativeFailure(value + 30)
def rc_raise_inspector(error: String) raises RCNativeFailure:
    raise RCNativeFailure(error.byte_length() + 40)
def rc_raise_retry(var error: String) raises RCNativeFailure -> Result[Int, Int]:
    raise RCNativeFailure(60)
def rc_raise_recovery(var error: String) raises RCNativeFailure -> Int:
    raise RCNativeFailure(error.byte_length() + 50)


@fieldwise_init
struct RCPredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref payload: Int) raises Never capturing -> Bool:
        return payload > 0


@fieldwise_init
struct RCErrorFactory(BorrowOnceCallable):
    var message: String
    comptime Payload = Int
    comptime Result = String
    def invoke_once(deinit self, ref payload: Int) raises Never capturing -> String:
        return self.message^


@fieldwise_init
struct RCNext(OnceThunk):
    var message: String
    comptime Out = Result[String, String]
    def call_once(deinit self) -> Self.Out:
        return Ok(self.message^)


@fieldwise_init
struct RCRecovery(MutableUnary):
    var calls: Int
    comptime Arg = String
    comptime Out = Int
    def call_mut(mut self, var arg: String) -> Int:
        self.calls += 1
        return arg.byte_length() + self.calls


def rc_branches() raises:
    assert_equal(rc_ok().flat_tap(rc_project).raise_on_err(), 3)
    var pair = rc_ok().flat_pair_with(rc_project).raise_on_err()
    assert_equal(pair[0], 3)
    assert_equal(pair[1], "3")
    assert_equal(rc_ok().followed_by(rc_next).raise_on_err(), "next")
    assert_equal(rc_ok().before(rc_next).raise_on_err(), 3)
    assert_equal(rc_failure(rc_ok().before(rc_bad_next)), "next error")
    assert_equal(rc_ok().ensure(rc_positive, rc_problem).raise_on_err(), 3)
    assert_equal(rc_failure(rc_ok(-2).ensure(rc_positive, rc_problem)), "rejected -2")
    assert_equal(rc_failure(rc_err().ensure(rc_positive, rc_problem)), "original")
    assert_equal(rc_err().recover(rc_recover).raise_on_err(), 8)
    comptime assert type_of(rc_err().recover(rc_recover)) == Result[Int, String]
    assert_equal(rc_ok().recover(rc_recover).raise_on_err(), 3)
    var calls = 0
    def rc_observe(error: String) {mut calls} -> Int:
        calls += error.byte_length()
        return 99
    assert_equal(rc_failure(rc_err().tap_err(rc_observe)), "original")
    assert_equal(calls, 8)
    assert_equal(rc_ok().tap_err(rc_observe).raise_on_err(), 3)
    assert_equal(calls, 8)
    assert_equal(rc_ok().followed_by(RCNext("owned")).raise_on_err(), "owned")
    assert_equal(rc_ok().before(RCNext("owned")).raise_on_err(), 3)
    assert_equal(rc_err().recover(RCRecovery(0)).raise_on_err(), 9)
    assert_equal(rc_failure(rc_ok(-1).ensure(RCPredicate(), RCErrorFactory("library"))), "library")
    assert_equal(rc_failure(rc_ok(-1).ensure(rc_positive, RCErrorFactory("mixed"))), "mixed")
    assert_equal(rc_failure(rc_ok(-1).ensure(RCPredicate(), rc_problem)), "rejected -1")


def rc_skipped_and_eager() raises:
    var calls = ArcPointer(0)
    def rc_projection(value: Int) {calls} -> Result[String, String]:
        calls[] += 1
        return Err(String("projection"))
    def rc_factory() {calls} -> Result[String, String]:
        calls[] += 1
        return Ok(String("produced"))
    def rc_predicate(value: Int) {calls} -> Bool:
        calls[] += 1
        return True
    def rc_make_error(value: Int) {calls} -> String:
        calls[] += 100
        return "unused"
    assert_equal(rc_failure(rc_err().flat_tap(rc_projection)), "original")
    assert_true(rc_err().flat_pair_with(rc_projection).is_err())
    assert_true(rc_err().followed_by(rc_factory).is_err())
    assert_equal(rc_failure(rc_err().before(rc_factory)), "original")
    assert_equal(rc_failure(rc_err().ensure(rc_predicate, rc_make_error)), "original")
    assert_equal(calls[], 0)
    var result = rc_ok().flat_tap(rc_projection)
    assert_equal(calls[], 1)
    assert_equal(rc_failure(result^), "projection")
    assert_true(rc_ok().flat_pair_with(rc_projection).is_err())
    assert_equal(calls[], 2)
    var pipeline = pipeline(rc_ok()).before(rc_factory).ensure(rc_predicate, rc_make_error)
    assert_equal(calls[], 4)
    assert_equal(pipeline^.get().raise_on_err(), 3)
    assert_equal(calls[], 4)


def rc_native_errors() raises:
    var code = 0
    try: _ = rc_ok().flat_tap(rc_raise_projection)
    except err: code = err.code
    assert_equal(code, 3)
    try: _ = rc_ok().flat_pair_with(rc_raise_projection)
    except err: code = err.code
    assert_equal(code, 3)
    try: _ = rc_ok().followed_by(rc_raise_factory)
    except err: code = err.code
    assert_equal(code, 11)
    try: _ = rc_ok().before(rc_raise_factory)
    except err: code = err.code
    assert_equal(code, 11)
    try: _ = rc_ok().ensure(rc_raise_predicate, rc_problem)
    except err: code = err.code
    assert_equal(code, 23)
    try: _ = rc_ok(-1).ensure(rc_positive, rc_raise_error)
    except err: code = err.code
    assert_equal(code, 29)
    try: _ = rc_ok(-1).ensure(RCPredicate(), rc_raise_error)
    except err: code = err.code
    assert_equal(code, 29)
    try: _ = rc_ok().ensure(rc_raise_predicate, RCErrorFactory("unused"))
    except err: code = err.code
    assert_equal(code, 23)
    try: _ = rc_ok().ensure(rc_raise_predicate, rc_raise_error)
    except err: code = err.code
    assert_equal(code, 23)
    try: _ = rc_err().tap_err(rc_raise_inspector)
    except err: code = err.code
    assert_equal(code, 48)
    try: _ = rc_err().recover(rc_raise_recovery)
    except err: code = err.code
    assert_equal(code, 58)
    # An identical native/stored type still remains a native exception.
    def rc_raise_stored_type(value: Int) raises String -> Result[Int, String]:
        raise String("raised")
    try: _ = rc_ok().flat_tap(rc_raise_stored_type).recover(rc_recover)
    except err: assert_equal(err, "raised")
    var skipped = True
    try:
        skipped = skipped and rc_err().flat_tap(rc_raise_projection).is_err()
        skipped = skipped and rc_err().flat_pair_with(rc_raise_projection).is_err()
        skipped = skipped and rc_err().followed_by(rc_raise_factory).is_err()
        skipped = skipped and rc_err().before(rc_raise_factory).is_err()
        skipped = skipped and rc_err().ensure(rc_raise_predicate, rc_raise_error).is_err()
        skipped = skipped and rc_ok().tap_err(rc_raise_inspector).is_ok()
        skipped = skipped and rc_ok().recover(rc_raise_recovery).is_ok()
    except err:
        skipped = False
    assert_true(skipped)


def rc_piped() raises:
    assert_equal(pipeline(rc_ok()).flat_tap(rc_project).flat_pair_with(rc_project).get().raise_on_err()[1], "3")
    assert_equal(pipeline(rc_ok()).followed_by(rc_next).get().raise_on_err(), "next")
    assert_equal(pipeline(rc_ok()).before(rc_next).get().raise_on_err(), 3)
    assert_equal(pipeline(rc_err()).map_err(rc_error).or_else(rc_retry).get().raise_on_err(), 18)
    var count = 0
    def rc_log(error: String) {mut count}: count += 1
    assert_equal(pipeline(rc_err()).tap_err(rc_log).recover(rc_recover).get().raise_on_err(), 8)
    assert_equal(count, 1)
    assert_equal(pipeline(rc_ok()).ensure(RCPredicate(), RCErrorFactory("unused")).get().raise_on_err(), 3)
    assert_equal(pipeline(rc_ok()).ensure(rc_positive, RCErrorFactory("unused")).get().raise_on_err(), 3)
    assert_equal(pipeline(rc_ok()).ensure(RCPredicate(), rc_problem).get().raise_on_err(), 3)
    var code = 0
    try: _ = pipeline(rc_ok()).flat_tap(rc_raise_projection)
    except err: code = err.code
    assert_equal(code, 3)
    try: _ = pipeline(rc_ok()).flat_pair_with(rc_raise_projection)
    except err: code = err.code
    assert_equal(code, 3)
    try: _ = pipeline(rc_ok()).followed_by(rc_raise_factory)
    except err: code = err.code
    assert_equal(code, 11)
    try: _ = pipeline(rc_ok()).before(rc_raise_factory)
    except err: code = err.code
    assert_equal(code, 11)
    try: _ = pipeline(rc_ok(-1)).ensure(rc_positive, rc_raise_error)
    except err: code = err.code
    assert_equal(code, 29)
    try: _ = pipeline(rc_err()).tap_err(rc_raise_inspector)
    except err: code = err.code
    assert_equal(code, 48)
    try: _ = pipeline(rc_err()).recover(rc_raise_recovery)
    except err: code = err.code
    assert_equal(code, 58)
    try: _ = pipeline(rc_err()).map_err(rc_raise_recovery)
    except err: code = err.code
    assert_equal(code, 58)
    try: _ = pipeline(rc_err()).or_else(rc_raise_retry)
    except err: code = err.code
    assert_equal(code, 60)


def main() raises:
    rc_branches()
    rc_skipped_and_eager()
    rc_native_errors()
    rc_piped()
