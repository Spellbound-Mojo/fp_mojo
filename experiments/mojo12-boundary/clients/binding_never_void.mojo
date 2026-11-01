from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int

def mutable_void(mut value: Int): value += 1
def mutable_never(mut value: Int) raises Never: value += 1
def owned_void(var value: String): _ = value^
def owned_never(var value: String) raises Never: _ = value^
def mixed_void(mut value: Int, var text: String): value += text.byte_length()
def mixed_never(mut value: Int, var text: String) raises Never: value += text.byte_length()
def keyword_void(mut value: Int, var text: String, /, var **options: Int):
    value += text.byte_length()
    for option in options.items(): value += option.value
def keyword_never(mut value: Int, var text: String, /, var **options: Int) raises Never:
    value += text.byte_length()
    for option in options.items(): value += option.value
def main() raises:
    var state = 0
    var a = Capture[Fault].mutating(mutable_void).run(state)
    comptime assert type_of(a) == Result[type_of(None), Never]
    assert_equal(a.is_ok(), True)
    assert_equal(Capture[Never].mutating(mutable_never).run(state).is_ok(), True)
    assert_equal(Capture[Fault].consuming(owned_void).run(String("a")).is_ok(), True)
    assert_equal(Capture[Never].consuming(owned_never).run(String("a")).is_ok(), True)
    assert_equal(Capture[Fault].mut_owned(mixed_void).run(state, String("ab")).is_ok(), True)
    assert_equal(Capture[Never].mut_owned(mixed_never).run(state, String("ab")).is_ok(), True)
    assert_equal(Capture[Fault].mut_owned_kwargs(keyword_void).run(state, String("a")).is_ok(), True)
    assert_equal(state, 7)
