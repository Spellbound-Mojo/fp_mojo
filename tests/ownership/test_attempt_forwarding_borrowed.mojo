"""Borrowed Lists and captured owners remain usable through repeated attempt calls."""
from fp.data import attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct AttemptForwardingBorrowedFailure(Movable):
    var code: Int

def inspect(values: List[Int], offset: String) -> Int:
    return len(values) + offset.byte_length()

def check(anchor: List[Int]) raises:
    var calls = 0
    def captured(value: Int) {anchor, mut calls} -> Int:
        calls += 1
        return anchor[0] + value
    def fail(value: Int) raises AttemptForwardingBorrowedFailure {anchor, mut calls} -> Int:
        calls += 1
        raise AttemptForwardingBorrowedFailure(anchor[0] + value)
    for i in range(3):
        assert_equal(raise_on_err(attempt(captured, i)), anchor[0] + i)
        var code = 0
        try: _ = raise_on_err(attempt(fail, i))
        except error: code = error.code
        assert_equal(code, anchor[0] + i)
    assert_equal(calls, 6)

def main() raises:
    var values: List[Int] = [7, 8, 9]
    var offset = String("xy")
    assert_equal(raise_on_err(attempt(inspect, values, offset)), inspect(values, offset))
    check(values)
    assert_equal(values, [7, 8, 9])
    assert_equal(offset, "xy")
