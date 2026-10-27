"""Return a plain value, compute a lazy default, or keep only a success."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal


def checked(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative count"))
    return Ok(value)


def double(value: Int) -> Int: return value * 2


def report(var error: String) -> Int:
    print("using zero:", error)
    return 0


def main() raises:
    print("value:", checked(21).map(double).value_or(report))
    print("fallback:", checked(-1).value_or(report))

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
