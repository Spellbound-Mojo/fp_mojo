"""Pair composition agrees with sequential composition on each side."""
from fp.functions import split, flow, Identity
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def double(var value: Int) -> Int: return value * 2
def render(var value: Int) -> String: return String(value)
def decorate(var value: String) -> String: return value + "!"

def main() raises:
    var identity = split(Identity[Int](), Identity[String]())
    var sequential = flow(split(increment, render), split(double, decorate))
    var combined = split(flow(increment, double), flow(render, decorate))
    for a in range(-3, 4):
        for b in range(-3, 4):
            assert_equal(identity((a, String(b))), (a, String(b)))
            assert_equal(sequential((a, b)), combined((a, b)))
