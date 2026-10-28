"""Finish an Optional pipeline with a lazy default, using the Result spelling."""
from fp.functions import pipeline
from fp.callables import Thunk
from fp.data import Result, Err
from std.testing import assert_equal

@fieldwise_init
struct DefaultHost(Thunk):
    comptime Out = String
    var host: String
    def call(self) -> String: return self.host.copy()


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
    var factory = DefaultHost(String("localhost"))
    var optional_default = pipeline(Optional[String]()).get_or_else(factory)
    var result_default = Result[String,Int](Err(0)).get_or_else(factory)
    print("reused defaults:", optional_default, result_default)
    var error = pipeline(Optional[String]()).to_result(factory).swap().get_or(String())
    print("reused error:", error)
