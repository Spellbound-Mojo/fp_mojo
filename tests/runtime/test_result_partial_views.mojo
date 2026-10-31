"""Direct and family-specific Result operations reuse borrowed partial callbacks."""
from fp.functions import partial, pipeline
from fp.data import ok, err, Result
from fp.algebra import ResultFamily
from std.testing import assert_equal

def above(limit: Int, value: Int) -> Bool: return value > limit
def label(var prefix: String, value: Int) -> String: return prefix + String(value)
def observe(var prefix: String, value: Int) -> Int: return prefix.byte_length() + value
def effect(var prefix: String, value: Int) -> Result[String, Int]: return ok[Int](prefix + String(value))
def outcome(var prefix: String, value: Result[String, Int]) -> Result[String, Int]:
    return ok[Int](prefix + String(value.is_ok()))
def main() raises:
    var predicate = partial(above, 2)
    var format = partial(label, String("value: "))
    assert_equal(ok[Int](3).fold(format, format), "value: 3")
    assert_equal(ok[String](3).ensure(predicate, format).get_or(0), 3)
    assert_equal(ok[String](1).ensure(predicate, format).swap().get_or(""), "value: 1")
    assert_equal(pipeline(ok[String](1)).ensure(predicate, format).get().swap().get_or(""), "value: 1")
    var observer = partial(observe, String("value: "))
    assert_equal(err[String](3).tap_err(observer).swap().get_or(0), 3)
    assert_equal(pipeline(err[String](4)).tap_err(observer).get().swap().get_or(0), 4)
    var effectful = partial(effect, String("value: "))
    assert_equal(err[String](5).flat_tap_err(effectful).swap().get_or(0), 5)
    var whole = partial(outcome, String("value: "))
    assert_equal(err[String](6).attempt_tap(whole).swap().get_or(0), 6)
    assert_equal(pipeline[ResultFamily[Int]](err[String](4)).tap_err(observer).get().swap().get_or(0), 4)
    assert_equal(err[String](4).recover_if(predicate, format).get_or(""), "value: 4")
    assert_equal(pipeline[ResultFamily[Int]](err[String](4)).recover_if(predicate, format).get().get_or(""), "value: 4")
    assert_equal(err[String](1).recover_if(predicate, format).swap().get_or(0), 1)
    assert_equal(pipeline[ResultFamily[Int]](err[String](1)).recover_if(predicate, format).get().swap().get_or(0), 1)
