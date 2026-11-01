"""Two-branch Result composition selects only the original branch."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.callables import OnceUnary, MutableUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def ro_ok(value: Int) -> Result[Int, String]: return Ok(value)
def ro_err() -> Result[Int, String]: return Err(String("missing"))
def ro_map(value: Int) -> String: return "value=" + String(value)
def ro_code(var error: String) -> Int: return error.byte_length()
def ro_recover(var error: String) -> String: return "recovered " + error
def ro_continue(value: Int) -> Result[String, Int]: return Ok(ro_map(value))
def ro_retry(var error: String) -> Result[String, Int]: return Err(error.byte_length())
def ro_fail(value: Int) -> Result[String, Int]: return Err(-value)
def ro_text(var value: String) -> String: return value^
def ro_number(value: Int) -> String: return String(value)
def ro_observe(value: Result[Int, String]) -> Result[Int, String]: return Ok(99)
def ro_reject(value: Result[Int, String]) -> Result[Int, String]: return Err(String("observer failed"))
def ro_message(var value: Result[Int, String]) -> String: return value^.fold_owned(ro_number, ro_text)


@fieldwise_init
struct ROMap(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = String
    def call_mut(mut self, var value: Int) -> String:
        self.calls += 1
        return ro_map(value + self.calls)


@fieldwise_init
struct RORecover(OnceUnary):
    var prefix: String
    comptime Arg = String
    comptime Out = String
    def call_once(deinit self, var error: String) -> String: return self.prefix + error


@fieldwise_init
struct ROContinue(OnceUnary):
    var prefix: String
    comptime Arg = Int
    comptime Out = Result[String, Int]
    def call_once(deinit self, var value: Int) -> Self.Out: return Ok(self.prefix + String(value))


@fieldwise_init
struct RORetry(OnceUnary):
    var code: Int
    comptime Arg = String
    comptime Out = Result[String, Int]
    def call_once(deinit self, var error: String) -> Self.Out: return Err(self.code)


@fieldwise_init
struct ROFailure(Movable):
    var code: Int


def ro_raise_ok(value: Int) raises ROFailure -> String: raise ROFailure(value)
def ro_raise_err(var error: String) raises ROFailure -> String: raise ROFailure(error.byte_length())
def ro_raise_next(value: Int) raises ROFailure -> Result[String, Int]: raise ROFailure(value)
def ro_raise_retry(var error: String) raises ROFailure -> Result[String, Int]: raise ROFailure(error.byte_length())
def ro_raise_observer(value: Result[Int, String]) raises ROFailure -> Result[Int, String]: raise ROFailure(81)


def main() raises:
    assert_equal(ro_ok(3).map_both(ro_map, ro_code).fold_owned(ro_text, ro_number), "value=3")
    assert_equal(ro_err().map_both(ro_map, ro_code).fold_owned(ro_text, ro_number), "7")
    assert_equal(ro_ok(3).redeem(ro_map, ro_recover).raise_on_err(), "value=3")
    assert_equal(ro_err().redeem(ro_map, ro_recover).raise_on_err(), "recovered missing")
    assert_equal(ro_ok(3).redeem_with(ro_continue, ro_retry).fold_owned(ro_text, ro_number), "value=3")
    assert_equal(ro_err().redeem_with(ro_continue, ro_retry).fold_owned(ro_text, ro_number), "7")
    # An Err returned by on_ok must not invoke the original on_err callback.
    assert_equal(ro_ok(3).redeem_with(ro_fail, ro_retry).fold_owned(ro_text, ro_number), "-3")
    assert_equal(ro_message(ro_ok(3).attempt_tap(ro_observe)), "3")
    assert_equal(ro_message(ro_err().attempt_tap(ro_observe)), "missing")
    assert_equal(ro_message(ro_ok(3).attempt_tap(ro_reject)), "observer failed")
    assert_equal(ro_message(ro_err().attempt_tap(ro_reject)), "observer failed")
    assert_equal(pipeline(ro_ok(4)).map_both(ro_map, ro_code).get().fold_owned(ro_text, ro_number), "value=4")
    assert_equal(pipeline(ro_err()).redeem(ro_map, ro_recover).get().raise_on_err(), "recovered missing")
    assert_equal(pipeline(ro_err()).redeem_with(ro_continue, ro_retry).get().fold_owned(ro_text, ro_number), "7")
    assert_equal(ro_message(pipeline(ro_err()).attempt_tap(ro_observe).get()), "missing")
    assert_equal(ro_ok(4).redeem(ROMap(0), RORecover("unused ")).raise_on_err(), "value=5")
    assert_equal(ro_err().redeem(ROMap(0), RORecover("owned ")).raise_on_err(), "owned missing")
    assert_equal(ro_ok(4).redeem(ROMap(1), ro_recover).raise_on_err(), "value=6")
    assert_equal(ro_err().redeem(ro_map, RORecover("mixed ")).raise_on_err(), "mixed missing")
    assert_equal(ro_ok(4).redeem_with(ROContinue("library="), ro_retry).fold_owned(ro_text, ro_number), "library=4")
    assert_equal(pipeline(ro_err()).redeem_with(ro_continue, RORetry(17)).get().fold_owned(ro_text, ro_number), "17")
    assert_equal(ro_ok(4).map_both(ROMap(0), ro_code).fold_owned(ro_text, ro_number), "value=5")
    assert_equal(ro_err().map_both(ro_map, RORecover("mapped ")).fold_owned(ro_text, ro_text), "mapped missing")
    var calls = ArcPointer(0)
    def ro_counted(value: Result[Int, String]) {calls} -> Result[Int, String]:
        calls[] += 1
        return Ok(calls[])
    var eager = pipeline(ro_err()).attempt_tap(ro_counted)
    assert_equal(calls[], 1)
    assert_true(eager^.get().is_err())
    var code = 0
    try: _ = ro_ok(21).redeem(ro_raise_ok, ro_recover)
    except error: code = error.code
    assert_equal(code, 21)
    try: _ = ro_err().redeem(ro_map, ro_raise_err)
    except error: code = error.code
    assert_equal(code, 7)
    try: _ = ro_ok(22).map_both(ro_raise_ok, ro_raise_err)
    except error: code = error.code
    assert_equal(code, 22)
    try: _ = pipeline(ro_ok(23)).redeem_with(ro_raise_next, ro_raise_retry)
    except error: code = error.code
    assert_equal(code, 23)
    try: _ = ro_err().attempt_tap(ro_raise_observer)
    except error: code = error.code
    assert_equal(code, 81)
    print("Result outcomes: mapping, recovery, sequencing and observation")
