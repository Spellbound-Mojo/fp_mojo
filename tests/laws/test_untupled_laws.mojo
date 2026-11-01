"""Explicit pair adaptation is reversible and commutes with unary composition."""
from fp.functions import tupled, untupled, flow, split
from std.testing import assert_equal

def add(first: Int, second: Int) -> Int: return first + second
def subtract(first: Int, second: Int) -> Int: return first - second
def report(var pair: Tuple[Int, String]) -> String: return String(pair[0]) + pair[1]
def increment(var value: Int) -> Int: return value + 1
def double(var value: Int) -> Int: return value * 2

def main() raises:
    var sum = untupled(tupled(add))
    var difference = untupled(tupled(subtract))
    var restored = tupled(untupled(report))
    var before = untupled(flow(tupled(add), increment))
    var after = flow(untupled(tupled(add)), increment)
    var pair_transform = tupled(untupled(split(increment, double)))
    for a in range(-3, 4):
        for b in range(-3, 4):
            assert_equal(sum(a, b), add(a, b))
            assert_equal(difference(a, b), subtract(a, b))
            assert_equal(restored((a, String(b))), report((a, String(b))))
            assert_equal(before(a, b), after(a, b))
            assert_equal(pair_transform((a, b)), (increment(a), double(b)))
