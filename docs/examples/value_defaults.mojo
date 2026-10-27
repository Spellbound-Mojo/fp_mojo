"""Use a value for a constant default, or a factory to compute one lazily."""
from fp.data import err
from fp.functions import pipeline
from std.testing import assert_equal

def main() raises:
    var count = pipeline(Optional[Int]()).get_or(0)
    var host = err[String]("missing host").get_or("localhost")
    assert_equal(count, 0)
    assert_equal(host, "localhost")
    print("count:", count)
    print("host:", host)

    var calls = 0
    def compute_default() {mut calls} -> Int:
        calls += 1
        return 7
    # An ordinary argument is evaluated before the method is called.
    assert_equal(pipeline(Optional(3)).get_or(compute_default()), 3)
    assert_equal(calls, 1)
    # Passing the factory itself keeps its evaluation lazy.
    assert_equal(pipeline(Optional(3)).get_or_else(compute_default), 3)
    assert_equal(calls, 1)
    print("defaults computed:", calls)
