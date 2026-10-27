"""Finish an Optional pipeline with a lazy default, using the Result spelling."""
from fp.functions import pipeline
from std.testing import assert_equal

def main() raises:
    var calls = 0
    def default_host() {mut calls} -> String:
        calls += 1
        return String("localhost")
    var configured = pipeline(Optional(String("example.org"))).get_or_else(default_host)
    assert_equal(configured, "example.org")
    assert_equal(calls, 0)
    print("configured:", configured)
    var fallback = pipeline(Optional[String]()).get_or_else(default_host)
    assert_equal(fallback, "localhost")
    assert_equal(calls, 1)
    print("default:", fallback)
    print("defaults computed:", calls)
