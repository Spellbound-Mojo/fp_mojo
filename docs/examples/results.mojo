"""Domain errors remain distinct from raised callback failures."""
from fp.data import Result, Ok, Err, attempt, raise_on_err
from std.collections import StringDict
from std.testing import assert_equal

comptime Checked = Result[Int, String]

def positive(var value: Int) -> Checked:
    if value <= 0:
        return Err(String("expected a positive value"))
    return Ok(value)

def twice(var value: Int) -> Int:
    return value * 2

def success(value: Int) -> String:
    return "ok: " + String(value)

def failure(error: String) -> String:
    return "domain: " + error

def may_raise(var value: Int) raises String -> Int:
    if value == 21:
        raise String("callback failed")
    return value

def main() raises:
    var good = positive(21).map(twice)
    assert_equal(good.fold(success, failure), "ok: 42")
    print(good.fold(success, failure))
    var bad = positive(-1).map(twice)
    assert_equal(bad.is_err(), True)
    print(bad.fold(success, failure))
    var caught = False
    try:
        var value = positive(21).map(may_raise)
        print(value.fold(success, failure))
    except error:
        assert_equal(error, "callback failed")
        caught = True
        print("raised:", error)
    assert_equal(caught, True)

    # Explicitly capture the same native error as a Result value.
    var captured: Checked = attempt(may_raise, 21)
    assert_equal(captured.is_err(), True)
    caught = False
    try:
        _ = raise_on_err(captured^)
    except error:
        assert_equal(error, "callback failed")
        caught = True
    assert_equal(caught, True)

    # Forward a positional prefix and native keyword options.
    var calls = 0
    def scale(value: Int, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var factor = 1
        for entry in options.items():
            if entry.key == "factor": factor = entry.value
        return value * factor
    var scaled: Result[Int, Never] = attempt(scale, 7, factor=3)
    assert_equal(raise_on_err(scaled^), 21)
    assert_equal(calls, 1)
    var options = StringDict[Int]()
    options["factor"] = 4
    assert_equal(raise_on_err(attempt(scale, 7, **options^)), 28)
    assert_equal(calls, 2)

    # Changes made before a native error remain visible to the caller.
    var balance = 5
    def debit(mut value: Int, /, var **options: Int) raises String -> Int:
        for entry in options.items(): value -= entry.value
        if value < 0: raise String("overdrawn")
        return value
    var first_debit: Checked = attempt(debit, balance, amount=3)
    assert_equal(first_debit.is_ok(), True)
    assert_equal(balance, 2)
    var second_debit: Checked = attempt(debit, balance, amount=4)
    assert_equal(second_debit.is_err(), True)
    assert_equal(balance, -2)
