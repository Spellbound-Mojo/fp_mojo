from fp.data import Capture, Result
from fp.data.result import Capture as ResultCapture
from fp.callables import OnceThunk
from std.testing import assert_equal

@fieldwise_init
struct CaptureConvenienceOnce(OnceThunk):
    var value: String
    comptime Out = String
    comptime Error = Never
    def call_once(deinit self) -> String:
        return self.value^

def parse(var text: String) raises -> Int:
    if text == "bad": raise Error("bad input")
    return text.byte_length()

def pair(var a: String, var b: String) -> Int:
    return a.byte_length() + b.byte_length()

def answer() -> Int: return 7

def noop(): pass

def main() raises:
    comptime assert type_of(Capture().run(answer)) == Result[Int, Never]
    assert_equal(Capture().run(answer)._ok().value, 7)
    assert_equal(Capture.args("abc").run(parse)._ok().value, 3)
    assert_equal(Capture.args("bad").run(parse).is_err(), True)
    assert_equal(ResultCapture.args("a", "bc").run(pair)._ok().value, 3)
    comptime assert type_of(Capture().run(noop)) == Result[type_of(None), Never]
    assert_equal(Capture.args().run(noop).is_ok(), True)
    assert_equal(Capture().run(CaptureConvenienceOnce("owned"))._ok().value, "owned")
    var calls = 0
    def read(a: String, b: String) {mut calls} -> Int:
        calls += 1
        return a.byte_length() + b.byte_length()
    var value = String("abc")
    assert_equal(Capture.borrow(value).borrow(value).run(read)._ok().value, 6)
    assert_equal(calls, 1)
    # Native borrowing-to-consuming conversion remains legal.
    assert_equal(Capture.args(value, value).run(read)._ok().value, 6)
    assert_equal(calls, 2)
