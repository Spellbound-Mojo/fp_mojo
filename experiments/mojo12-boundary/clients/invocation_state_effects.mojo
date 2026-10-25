from fp._binding_state import Capture
from fp.data import Result
from std.testing import assert_equal

def pure(mut state: Int, var text: String) -> Int:
    state += text.byte_length()
    return state
def never(mut state: Int, var text: String) raises Never -> Int:
    state += text.byte_length()
    return state
def pure_void(mut state: Int, var text: String): state += text.byte_length()
def never_void(mut state: Int, var text: String) raises Never: state += text.byte_length()
def failure(mut state: Int, var text: String) raises -> Int:
    state += text.byte_length()
    raise Error("failed")
def failure_void(mut state:Int,var text:String) raises:
    state+=text.byte_length()
    raise Error("failed")
def main() raises:
    var a = Capture[Never].stateful(pure, 1)
    var x = a.run(String("ab"))
    comptime assert type_of(x) == Result[Int, Never]
    assert_equal(x._ok().value, 3)
    var b = Capture[Never].stateful(never, 1)
    assert_equal(b.run(String("ab"))._ok().value, 3)
    var c = Capture[Never].stateful(pure_void, 1)
    var v = c.run(String("ab"))
    comptime assert type_of(v) == Result[type_of(None), Never]
    assert_equal(v.is_ok(), True)
    assert_equal(c.state(), 3)
    var d = Capture[Never].stateful(never_void, 1)
    assert_equal(d.run(String("ab")).is_ok(), True)
    assert_equal(d.state(), 3)
    var e = Capture[Error].stateful(failure, 1)
    assert_equal(e.run(String("ab")).is_err(), True)
    assert_equal(e.state(), 3)
    var f = Capture[Error].stateful(failure_void, 1)
    assert_equal(f.run(String("ab")).is_err(), True)
    assert_equal(f.state(), 3)
