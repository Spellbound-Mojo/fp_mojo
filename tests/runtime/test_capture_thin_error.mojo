from fp.data import Capture
from std.testing import assert_equal, assert_true
@fieldwise_init
struct Fault(Movable):
    var code: Int
def failing() raises Fault -> Int: raise Fault(7)
def text_failing(var value: Int) raises String -> Int:
    if value < 0: raise String("negative")
    return value + 1
def main() raises:
    # Under the default context, a raising plain function keeps its own error.
    assert_equal(Capture().run(failing)._err().value.code, 7)
    assert_equal(Capture().args(2).run(text_failing)._ok().value, 3)
    assert_equal(Capture().take(-1).run(text_failing)._err().value, "negative")
    # Closures still raise the selected error, Error by default.
    var calls = 0
    def closure() raises {mut calls} -> Int:
        calls += 1
        raise Error("closure")
    assert_true(Capture().run(closure).is_err())
    assert_equal(calls, 1)
    # An explicit error still governs closures and matching plain functions.
    assert_equal(Capture[Fault]().run(failing)._err().value.code, 7)
