"""Native thin callables already forward existing heterogeneous packs.

This does not establish captured callable forwarding or pack concatenation.
"""
from std.testing import assert_equal


def invoke[R: Movable & Deinitable, *Args: Movable & Deinitable](
    function: def(*args: *Args) thin -> R, *values: *Args
) -> R:
    return function(*values)


def combine(a: Int, b: String, c: Bool) -> String:
    return String(a) + b + String(c)


def empty() -> Int:
    return 42


def main() raises:
    assert_equal(invoke(combine, 2, String("x"), True), "2xTrue")
    assert_equal(invoke(empty), 42)
