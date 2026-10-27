"""Bind an accumulator, then infer the effect from the fold step."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal

def main() raises:
    var calls = 0
    def add(var total: Int, var amount: Int) {mut calls} -> Result[Int, String]:
        calls += 1
        if amount < 0: return Err(String("negative amount"))
        return Ok(total + amount)
    var total = pipeline(List[Int]([1, 2, 3])).fold_effect(10).run(add).get_or(0)
    assert_equal(total, 16)
    assert_equal(calls, 3)
    print("total:", total)
    calls = 0
    var reason = pipeline(List[Int]([1, -2, 99])).fold_effect(0).run(add).swap().get_or("")
    assert_equal(reason, "negative amount")
    assert_equal(calls, 2)
    print("error:", reason)
    print("steps:", calls)
    assert_equal(pipeline(List[Int]()).fold_effect(10).run(add).get_or(0), 10)
    assert_equal(calls, 2)
