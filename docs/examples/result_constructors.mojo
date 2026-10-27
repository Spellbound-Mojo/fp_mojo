"""Construct complete Results while naming only the missing side's type."""
from fp.data import Result, Ok, Err, ok, err
from fp.functions import pipeline
from std.testing import assert_equal

def double(value: Int) -> Int: return value * 2
def explain(var error: String) -> Int: return error.byte_length()

def checked(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value)

def main() raises:
    var accepted = ok[String](21)
    comptime assert type_of(accepted) == Result[Int, String]
    var rejected = err[Int]("missing")
    comptime assert type_of(rejected) == Result[Int, String]
    var total = pipeline(accepted^).map(double).value_or(explain)
    assert_equal(total, 42)
    print("accepted:", total)
    var recovered = rejected^.value_or(explain)
    assert_equal(recovered, 7)
    print("fallback:", recovered)
    assert_equal(checked(4).value_or(explain), 4)
