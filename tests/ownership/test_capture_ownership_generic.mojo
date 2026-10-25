from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal

@fieldwise_init
struct CaptureOwnershipGenericFault(Movable):
    var code: Int

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) raises E -> R](function: F, mut state: A, var value: B, /, var **options: K) -> Result[R, E]:
    var pending = Capture[E].mutable(state).take(value^).kwargs(**options^)
    return pending^.run(function)

def callback(mut state: Int, var text: String, /, var **options: Int) raises CaptureOwnershipGenericFault -> Int:
    state += text.byte_length()
    for item in options.items(): state += item.value
    raise CaptureOwnershipGenericFault(state)

def main() raises:
    var state = 1
    assert_equal(forward(callback, state, String("ab"), extra=3)._err().value.code, 6)
    assert_equal(state, 6)
