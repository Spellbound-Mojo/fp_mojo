"""A Result pipeline finishes with exactly one handler's plain value."""
from fp.data import Result, ok, err
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from std.testing import assert_equal


def success(var value: Int) -> String: return "ok " + String(value)
def failure(var error: String) -> String: return "error " + error
def length(var value: String) -> Int: return value.byte_length()
def never(var value: Int) raises Never -> Int: return value + 1
def plain(var value: Int) -> Int: return value * 2


def forward[T: Movable & Deinitable, E: Movable & Deinitable,
            R: Movable & Deinitable, X: Movable & Deinitable, //,
            F: def(var T) raises X -> R, G: def(var E) raises X -> R](
    var source: Result[T, E], on_ok: F, on_err: G
) raises X -> R:
    return pipeline(source^).raising[X]().fold_owned(on_ok, on_err)


def main() raises:
    assert_equal(pipeline(ok[String](7)).fold_owned(success, failure), "ok 7")
    assert_equal(pipeline(err[Int](String("missing"))).fold_owned(success, failure), "error missing")
    assert_equal(pipeline[IdentityFamily](ok[String](3)).fold_owned(success, failure), "ok 3")
    var on_ok: def(var Int) thin -> String = success
    var on_err: def(var String) thin -> String = failure
    assert_equal(pipeline(ok[String](9)).fold_owned(on_ok, on_err), "ok 9")
    assert_equal(pipeline(err[Int](String("pointer"))).fold_owned(on_ok, on_err), "error pointer")
    var first: def(var String) thin -> Int = length
    assert_equal(pipeline(ok[String](String("four"))).fold_owned(first, first), 4)
    assert_equal(pipeline(ok[Int](2)).raising[Int]().fold_owned(never, plain), 3)
    assert_equal(pipeline(err[Int](2)).raising[Never]().fold_owned(never, never), 3)
    assert_equal(forward(ok[Int](4), never, never), 5)

    var observed = 0
    var skipped = 0
    def observe(var value: Int) {mut observed}: observed += value
    def unused(var value: String) {mut skipped}: skipped += 1
    _ = pipeline(ok[String](3)).fold_owned(observe, unused)
    assert_equal(observed, 3)
    assert_equal(skipped, 0)

    var calls = 0
    var failures = 0
    def accepted(var value: Int) raises Int {mut calls} -> String:
        calls += 1
        if value < 0: raise 11
        return String(value)
    def rejected(var error: String) raises Int {mut failures} -> String:
        failures += 1
        raise error.byte_length()
    assert_equal(forward(ok[String](5), accepted, rejected), "5")
    assert_equal(calls, 1)
    var caught = False
    try:
        _ = pipeline(ok[String](-1)).raising[Int]().fold_owned(accepted, rejected)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 11)
        caught = True
    assert_equal(caught, True)
    assert_equal(calls, 2)
    caught = False
    try:
        _ = forward(err[Int](String("bad")), accepted, rejected)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 3)
        caught = True
    assert_equal(caught, True)
    assert_equal(calls, 2)
    assert_equal(failures, 1)
