from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int

def mutable[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A) raises E -> R](function: F, mut value: A) -> Result[R, E]:
    return Capture[E].mutating(function).run(value)
def owned[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
          F: def(var A) raises E -> R](function: F, var value: A) -> Result[R, E]:
    return Capture[E].consuming(function).run(value^)
def mixed[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
          E: Movable & Deinitable, //, F: def(mut A, var B) raises E -> R](function: F, mut first: A, var second: B) -> Result[R, E]:
    return Capture[E].mut_owned(function).run(first, second^)
def keyword[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
            R: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, var B, /, var **kwargs: K) raises E -> R](function: F, mut first: A, var second: B, /, var **values: K) -> Result[R, E]:
    return Capture[E].mut_owned_kwargs(function).run(first, second^, **values^)
def main() raises:
    var bias = String("abcd")
    def a(mut value: Int) raises Fault {bias} -> Int:
        value += bias.byte_length()
        raise Fault(value)
    def b(var value: String) raises Fault {bias} -> String:
        return value + bias
    def c(mut value: Int, var text: String) raises Fault {bias} -> Int:
        value += text.byte_length() + bias.byte_length()
        raise Fault(value)
    def d(mut value: Int, var text: String, /, var **options: Int) raises Fault {bias} -> Int:
        value += text.byte_length() + bias.byte_length()
        for entry in options.items(): value += entry.value
        raise Fault(value)
    var state = 1
    assert_equal(mutable(a, state)._err().value.code, 5)
    assert_equal(owned(b, String("x"))._ok().value, "xabcd")
    assert_equal(mixed(c, state, String("ab"))._err().value.code, 11)
    assert_equal(keyword(d, state, String("ab"), extra=3)._err().value.code, 20)
    assert_equal(state, 20)
