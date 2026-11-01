from fp._argument_staged import Capture
from std.testing import assert_equal
@fieldwise_init
struct Fault(Movable):
    var code: Int
def f(mut state: Int, var text: String, /, var **values: Int) raises Fault -> Int:
    state += text.byte_length()
    for v in values.items(): state += v.value
    raise Fault(state)
def main() raises:
    var state=1
    var result=Capture[Fault].kwargs(state, "ab", extra=3).run(f)
    assert_equal(result._err().value.code,6)
    assert_equal(state,6)
