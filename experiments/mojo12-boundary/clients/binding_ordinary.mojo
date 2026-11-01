from fp._binding_architecture import Capture
from std.testing import assert_equal
@fieldwise_init
struct Fault(Movable):
    var code: Int
def update(mut value: Int) raises Fault -> Int:
    value += 3
    if value > 5: raise Fault(value)
    return value
def parse(var text: String) raises Fault -> Int:
    return text.byte_length()
def send(mut state: Int, var text: String) raises Fault -> Int:
    state += text.byte_length()
    raise Fault(state)
def debit(mut state: Int, var text: String, /, var **values: Int) raises Fault -> Int:
    state += text.byte_length()
    for value in values.items(): state += value.value
    raise Fault(state)
def main() raises:
    var state = 0
    var updates = Capture[Fault].mutating(update)
    assert_equal(updates.run(state)._ok().value, 3)
    assert_equal(updates.run(state)._err().value.code, 6)
    assert_equal(Capture[Fault].consuming(parse).run(String("abc"))._ok().value, 3)
    assert_equal(Capture[Fault].mut_owned(send).run(state, String("abc"))._err().value.code, 9)
    assert_equal(Capture[Fault].mut_owned_kwargs(debit).run(state, String("a"), extra=2)._err().value.code, 12)
    assert_equal(state, 12)
