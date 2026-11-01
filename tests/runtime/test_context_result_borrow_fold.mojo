"""Borrowing Result handlers finish a pipeline without ownership annotations."""
from fp.data import Result, ok, err
from fp.functions import pipeline
from std.testing import assert_equal


def length(value: String) -> Int: return value.byte_length()
def number(value: Int) -> String: return String(value)
def text(value: String) -> String: return "error " + value
def never(value: Int) raises Never -> Int: return value + 1


def forward[T: Movable & Deinitable, E: Movable & Deinitable,
            R: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, q: ImmOrigin, //,
            F: def(T) raises X -> R, G: def(E) raises X -> R](
    var source: Result[T, E], ref[o] on_ok: F, ref[q] on_err: G
) raises X -> R:
    return pipeline(source^).raising[X]().fold(on_ok, on_err)


def main() raises:
    assert_equal(pipeline(ok[String](7)).fold(number, text), "7")
    assert_equal(pipeline(err[Int](String("bad"))).fold(number, text), "error bad")
    var on_ok: def(Int) thin -> String = number
    var on_err: def(String) thin -> String = text
    assert_equal(pipeline(err[Int](String("pointer"))).fold(on_ok, on_err), "error pointer")
    var read: def(String) thin -> Int = length
    assert_equal(pipeline(ok[String](String("four"))).fold(read, read), 4)
    assert_equal(pipeline(ok[Int](2)).raising[Int]().fold(never, never), 3)
    # Forward a real closure value; bare read-function promotion has a separate
    # native-only reproducer under experiments/mojo12-diagnostics.
    var bias = 1
    def shared(value: Int) raises Never {bias} -> Int: return value + bias
    assert_equal(forward(err[Int](4), shared, shared), 5)

    var seen = 0
    var skipped = 0
    def observe(value: Int) {mut seen}: seen += value
    def unused(value: String) {mut skipped}: skipped += value.byte_length()
    _ = pipeline(ok[String](3)).fold(observe, unused)
    assert_equal(seen, 3)
    assert_equal(skipped, 0)

    var calls = 0
    var failures = 0
    def success(value: String) raises Int {mut calls} -> Int:
        calls += 1
        return value.byte_length()
    def failure(value: String) raises Int {mut failures} -> Int:
        failures += 1
        raise value.byte_length()
    assert_equal(forward(ok[String](String("first")), success, failure), 5)
    var caught = False
    try:
        _ = forward(err[String](String("bad")), success, failure)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 3)
        caught = True
    assert_equal(caught, True)
    assert_equal(calls, 1)
    assert_equal(failures, 1)
