from fp.functions import pipe
from fp.data import Result, Ok, Err, attempt, raise_on_err
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Failure(Copyable, Writable):
    var code: Int


def reject(var value: Int) raises Failure -> Int:
    raise Failure(value + 7)


def main() raises:
    var calls = 0
    def fail() raises Failure {mut calls} -> String:
        calls += 1
        raise Failure(42)
    var captured = attempt(fail)
    assert_equal(calls, 1)
    assert_true(captured.is_err())
    var code = -1
    try:
        _ = raise_on_err(captured^)
    except error:
        code = error.code
    assert_equal(code, 42)

    def succeed() raises Failure -> String:
        return "value"
    var success = attempt(succeed)
    var output = String("")
    try:
        output = raise_on_err(success^)
    except error:
        raise Error("unexpected failure")
    assert_equal(output, "value")

    var later_calls = 0
    def later(var value: Int) {mut later_calls} -> Int:
        later_calls += 1
        return value * 3
    try:
        _ = pipe(pipe(5, reject), later)
    except error:
        assert_equal(error.code, 12)
    assert_equal(later_calls, 0)
