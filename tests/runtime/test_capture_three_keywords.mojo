"""Three positional operands compose with owned homogeneous keyword packs."""
from fp.data import Capture, Result
from std.testing import assert_equal


def record(mut state: Int, rate: Int, var label: String, /, var **options: Int) raises String -> String:
    state += rate
    for item in options.values(): state += item
    if state > 10: raise String("too much")
    return label + ":" + String(state)


def owned(var a: String, var b: String, var c: String, /, var **options: Int) raises Int -> String:
    if len(options) > 0: raise 17
    return a + b + c


def forward[A: Movable & Deinitable, B: Movable & Deinitable, C: Movable & Deinitable,
            K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, B, var C, /, var **options: K) raises E -> R](
    function: F, mut state: A, borrowed: B, var payload: C, /, var **options: K
) -> Result[R, E]:
    return Capture[E].mutable(state).borrow(borrowed).take(payload^).kwargs(**options^).run(function)


def main() raises:
    var state = 0
    var rate = 3
    comptime CaptureErrors = Capture[String]
    var first = CaptureErrors.mutable(state).borrow(rate).take(String("first")).kwargs(extra=2).run(record)
    assert_equal(first._ok().value, "first:5")
    assert_equal(state, 5)
    var second = forward(record, state, rate, String("second"), extra=4)
    assert_equal(second._err().value, "too much")
    assert_equal(state, 12)
    var plain = Capture[Int].args(String("a"), String("b"), String("c")).kwargs[K=Int]().run(owned)
    assert_equal(plain._ok().value, "abc")
    var pointer: def(var String, var String, var String, /, var **kwargs: Int) raises Int thin -> String = owned
    var failed = Capture[Int].args(String("a"), String("b"), String("c")).kwargs(fail=1).run(pointer)
    assert_equal(failed._err().value, 17)
