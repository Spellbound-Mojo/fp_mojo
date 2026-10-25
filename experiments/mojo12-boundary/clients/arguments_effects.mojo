from fp._argument_staged import Capture
from fp.data import Result
from std.testing import assert_equal

def pure(mut state: Int, var text: String, /, var **options: Int) -> Int:
    state += text.byte_length()
    for item in options.items(): state += item.value
    return state

def pure_void(mut state: Int, var text: String, /, var **options: Int):
    _ = pure(state, text^, **options^)

def never(mut state: Int, var text: String, /, var **options: Int) raises Never -> Int:
    return pure(state, text^, **options^)

def never_void(mut state: Int, var text: String, /, var **options: Int) raises Never:
    _ = pure(state, text^, **options^)

def failure_void(mut state: Int, var text: String, /, var **options: Int) raises:
    _ = pure(state, text^, **options^)
    raise Error("failure")

def main() raises:
    var state = 0
    var a = Capture[Error].kwargs(state, "a", extra=1).run(pure)
    comptime assert type_of(a) == Result[Int, Never]
    assert_equal(a._ok().value, 2)
    var b = Capture[Error].kwargs(state, "a", extra=1).run(pure_void)
    comptime assert type_of(b) == Result[type_of(None), Never]
    assert_equal(b.is_ok(), True)
    var c = Capture[Never].kwargs(state, "a", extra=1).run(never)
    comptime assert type_of(c) == Result[Int, Never]
    assert_equal(c._ok().value, 6)
    var d = Capture[Never].kwargs(state, "a", extra=1).run(never_void)
    comptime assert type_of(d) == Result[type_of(None), Never]
    assert_equal(d.is_ok(), True)
    var e = Capture[Error].kwargs(state, "a", extra=1).run(failure_void)
    assert_equal(String(e._err().value), "failure")
    assert_equal(state, 10)
    var calls = 0
    def captured(mut first: Int, var text: String, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        first += text.byte_length()
        for item in options.items(): first += item.value
    for n in range(1, 4):
        assert_equal(Capture[Never].kwargs(state, "a", extra=1).run(captured).is_ok(), True)
        assert_equal(calls, n)
    assert_equal(state, 16)

    var separate = 0
    var never_in_context = Capture[Error].kwargs(separate, "a", extra=1).run(never)
    comptime assert type_of(never_in_context) == Result[Int, Never]
    assert_equal(never_in_context._ok().value, 2)
    var void_in_context = Capture[Error].kwargs(separate, "a", extra=1).run(never_void)
    comptime assert type_of(void_in_context) == Result[type_of(None), Never]
    assert_equal(void_in_context.is_ok(), True)
    assert_equal(separate, 4)
