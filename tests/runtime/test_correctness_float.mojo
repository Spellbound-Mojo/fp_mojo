"""Identical native operation order; NaN classification and signed zero."""
from fp.iteration import fold_left
from fp.iteration import scan_left, collect_list
from std.iter import iter
from std.testing import assert_equal

def subtract(var a: Float64, var b: Float64) -> Float64: return a - b

def check(initial: Float64, values: List[Float64]) raises:
    var expected = initial
    var states = List[Float64]()
    states.append(expected)
    for value in values:
        expected = expected - value
        states.append(expected)
    var actual = fold_left(subtract, initial, iter(values))
    var scan = collect_list(scan_left(subtract, initial, iter(values)))
    assert_equal(len(scan), len(states))
    # NaNs need not preserve payload bits across compiler operations, but must
    # remain NaN. For zero, reciprocal infinity retains its sign.
    if expected != expected: assert_equal(actual != actual, True)
    else:
        assert_equal(actual, expected)
        if expected == 0: assert_equal(Float64(1) / actual, Float64(1) / expected)
    for i in range(len(states)):
        if states[i] != states[i]: assert_equal(scan[i] != scan[i], True)
        else:
            assert_equal(scan[i], states[i])
            if states[i] == 0: assert_equal(Float64(1) / scan[i], Float64(1) / states[i])

def main() raises:
    var negative_zero = Float64(-0.0)
    var nan = Float64(0) / Float64(0)
    check(negative_zero, List[Float64]())
    check(negative_zero, [Float64(0), negative_zero])
    check(Float64(1e20), [Float64(1e20), Float64(1), Float64(-1)])
    check(Float64(1), [nan, Float64(2)])
    check(nan, List[Float64]())
