"""Result handlers admit mixed native pointer conventions through one descriptor."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def text(var value: Int) -> String: return String(value)
def length(var value: String) -> Int: return value.byte_length()
def identity(var value: Int) -> Int: return value
# Native read arguments preserve their own convention.
def positive(value: Int) -> Bool: return value > 0
def reject(value: Int) -> String: return String(value)
def recovered(var value: Int) -> Result[String, Int]: return Ok(String(value))
def changed(var value: Int) -> Result[String, Bool]: return Ok(String(value))
def ok_side(var value: Int) -> Result[String, Bool]: return Ok(String(value))
def err_side(var value: String) -> Result[String, Bool]: return Ok(value^)
def observe(value: String): pass
def inspected(value: String) -> Result[Int, String]: return Ok(value.byte_length())
def factory() -> Result[Int, String]: return Ok(9)
def never_error(var value: String) raises Never -> Result[String, Bool]: return Ok(value^)
def result_failure(var value: Int) raises String -> Result[String, Bool]: raise String(value)
def failure(var value: Int) raises String -> String: raise String(value)

def main() raises:
    var convert: def(var Int) thin -> String = text
    var measure: def(var String) thin -> Int = length
    var keep: def(var Int) thin -> Int = identity
    var predicate: def(Int) thin -> Bool = positive
    var error: def(Int) thin -> String = reject
    var same: def(var Int) thin -> Result[String, Int] = recovered
    var alternate: def(var Int) thin -> Result[String, Bool] = changed
    assert_equal(pipeline(Result[Int, String](Ok(3))).map_both(convert, measure).get()._ok().value, "3")
    assert_equal(pipeline(Result[Int, String](Err(String("abc")))).map_both(convert, measure).get()._err().value, 3)
    assert_equal(pipeline(Result[Int, String](Err(String("abc")))).redeem(keep, measure).get()._ok().value, 3)
    var on_ok: def(var Int) thin -> Result[String, Bool] = ok_side
    var on_err: def(var String) thin -> Result[String, Bool] = err_side
    assert_equal(pipeline(Result[Int, String](Err(String("abc")))).redeem_with(on_ok, on_err).get()._ok().value, "abc")
    assert_equal(pipeline(Result[String, Int](Err(3))).recover(convert).get()._ok().value, "3")
    assert_equal(pipeline(Result[String, Int](Err(3))).recover_if(predicate, convert).get()._ok().value, "3")
    assert_equal(pipeline(Result[String, Int](Err(3))).or_else(alternate).get()._ok().value, "3")
    assert_equal(pipeline(Result[String, Int](Err(3))).or_else_if(predicate, same).get()._ok().value, "3")
    assert_equal(pipeline(Result[Int, String](Ok(-1))).ensure(predicate, error).get()._err().value, "-1")
    var borrowed: def(String) thin = observe
    var effect: def(String) thin -> Result[Int, String] = inspected
    var later: def() thin -> Result[Int, String] = factory
    assert_equal(pipeline(Result[Int, String](Err(String("bad")))).tap_err(borrowed).get()._err().value, "bad")
    assert_equal(pipeline(Result[String, String](Ok(String("abc")))).flat_tap(effect).get()._ok().value, "abc")
    assert_equal(pipeline(Result[String, String](Ok(String("abc")))).flat_pair_with(effect).get()._ok().value[1], 3)
    assert_equal(pipeline(Result[String, String](Ok(String("abc")))).before(later).get()._ok().value, "abc")
    assert_equal(pipeline(Result[String, String](Ok(String("abc")))).followed_by(later).get()._ok().value, 9)
    var raised: def(var Int) raises String thin -> String = failure
    var message = String()
    try: _ = pipeline(Result[Int, String](Ok(7))).raising[String]().map_both(raised, measure).get()
    except error: message = error^
    assert_equal(message, "7")
    # Infer an exact Never error for a thin memory-input/memory-result callback.
    var never: def(var String) raises Never thin -> Result[String, Bool] = never_error
    assert_equal(pipeline(Result[Int, String](Err(String("kept")))).raising[String]().redeem_with(on_ok, never).get()._ok().value, "kept")
    var value: Result[String, Bool]
    try: value = pipeline(Result[Int, String](Err(String("other")))).raising[String]().redeem_with(result_failure, never_error).get()
    except _: raise Error("unselected callback ran")
    assert_equal(value._ok().value, "other")
