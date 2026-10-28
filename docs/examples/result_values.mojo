"""Return a plain value, compute a lazy default, or keep only a success."""
from fp.data import Result, Ok, Err
from fp.algebra import IdentityFamily
from fp.functions import pipeline, kleisli
from std.testing import assert_equal


def checked(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative count"))
    return Ok(value)


def double(value: Int) -> Int: return value * 2
def describe(value: Int) -> String: return "count " + String(value)
def describe_error(error: String) -> String: return "invalid: " + error


def report(var error: String) -> Int:
    print("using zero:", error)
    return 0


def main() raises:
    var explain = kleisli[IdentityFamily](report)
    print("value:", checked(21).map(double).value_or(explain))
    print("fallback:", pipeline(checked(-1)).value_or(explain))

    var defaults = 0
    def default() {mut defaults} -> Int:
        defaults += 1
        return 7

    print("pipeline:", pipeline(checked(4)).map(double).get_or_else(default))
    assert_equal(defaults, 0)
    print("default:", checked(-1).get_or_else(default))
    assert_equal(defaults, 1)

    var optional = checked(5).to_optional()
    if optional: print("optional:", optional.value())
    assert_equal(Bool(checked(-1).to_optional()), False)

    # Swapping makes the stored error available to ordinary success operations.
    var reason = pipeline(checked(-1)).swap().to_optional()
    assert_equal(reason.value(), "negative count")
    print("reason:", reason.value())
    assert_equal(Bool(checked(5).swap().to_optional()), False)

    # Both handlers borrow their payload; the pipeline owns its cleanup.
    assert_equal(pipeline(checked(5)).fold(describe, describe_error), "count 5")
    print("summary:", pipeline(checked(-1)).fold(describe, describe_error))

    var nested = checked(6).map(checked)
    print("flattened:", nested^.flatten().get_or(0))
    var rejected = checked(-1).map(checked)
    print("flattened error:", rejected^.flatten().swap().get_or(String()))

    print("filled:", checked(5).fill(String("accepted")).get_or(String()))
    print("void:", checked(5).void().is_ok())
    print("void error:", checked(-1).void().swap().get_or(String()))
