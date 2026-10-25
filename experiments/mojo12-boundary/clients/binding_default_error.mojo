from fp._binding_architecture import Capture
from std.testing import assert_equal
def a(mut value: Int) raises -> Int:
    value += 1
    raise Error("failed")
def b(var value: String) raises -> Int: raise Error(value^)
def c(mut value: Int, var text: String) raises -> Int:
    value += text.byte_length()
    raise Error(text^)
def main() raises:
    var state = 0
    assert_equal(Capture[Error].mutating(a).run(state).is_err(), True)
    assert_equal(Capture[Error].consuming(b).run(String("failed")).is_err(), True)
    assert_equal(Capture[Error].mut_owned(c).run(state, String("ab")).is_err(), True)
    assert_equal(state, 3)
