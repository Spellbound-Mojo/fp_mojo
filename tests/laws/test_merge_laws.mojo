"""Pure merge agrees with split after duplication and with independent mapping."""
from fp.functions import merge, split, flow, Identity
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def double(var value: Int) -> Int: return value * 2
def render(var value: Int) -> String: return String(value)
def decorate(var value: String) -> String: return value + "!"

def main() raises:
    var both = merge(increment, render)
    var pair = split(increment, render)
    var sequential = both^.then(split(double, decorate))
    var combined = merge(flow(increment, double), flow(render, decorate))
    var duplicate = merge(Identity[Int](), Identity[Int]())
    for value in range(-5, 6):
        assert_equal(duplicate(value), (value, value))
        assert_equal(merge(increment, render)(value), pair((value, value)))
        assert_equal(sequential(value), combined(value))
