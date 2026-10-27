"""Parse and total in one pass, preserving the first stored error."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def main() raises:
    var calls = 0
    def amount(var text: String) {mut calls} -> Result[Int, String]:
        calls += 1
        var value: Int
        try: value = atol(text)
        except: return Err(String("invalid amount"))
        return Ok(value)
    var total = pipeline(List[String](["12", "15"])).sum_by_effect(amount).get_or(0)
    assert_equal(total, 27)
    print("total:", total)
    calls = 0
    var reason = pipeline(List[String](["12", "bad", "99"])).sum_by_effect(amount).swap().get_or("")
    assert_equal(reason, "invalid amount"); assert_equal(calls, 2)
    print("error:", reason)
    print("parsed:", calls)
    var known: List[Optional[Int]] = [Optional(2), Optional(3)]
    var summed = pipeline(known^).sum_effect().get_or(0)
    assert_equal(summed, 5)
    print("known:", summed)
