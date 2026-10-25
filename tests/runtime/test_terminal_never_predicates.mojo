"""Explicit Never read predicates preserve thin calls and closure forwarding."""
from fp.iteration import any, all, find, iterated
from std.testing import assert_equal

def predicate(value: Int) raises Never -> Bool:
    return value == 1

def forward[T: Copyable & Deinitable, //, F: def(T) raises Never -> Bool](
    function: F, values: List[T]
) -> Bool:
    return any[E=Never, F=F](function, values.copy())

def main() raises:
    assert_equal(any[E=Never](predicate, range(2)), True)
    assert_equal(all[E=Never](predicate, range(2)), False)
    assert_equal(find[E=Never](predicate, range(2)).value(), 1)
    assert_equal(iterated(range(2)).any[E=Never](predicate), True)
    assert_equal(iterated(range(2)).all[E=Never](predicate), False)
    assert_equal(iterated(range(2)).find[E=Never](predicate).value(), 1)
    var calls = 0
    def captured(value: Int) raises Never {mut calls} -> Bool:
        calls += 1
        return value == 1
    assert_equal(any[E=Never](captured, range(3)), True)
    assert_equal(calls, 2)
    assert_equal(iterated(range(3)).find[E=Never](captured).value(), 1)
    assert_equal(calls, 4)
    assert_equal(forward(captured, List[Int]([0, 1, 2])), True)
    assert_equal(calls, 6)
