# error: uninitialized value 'state'
from fp._argument_staged import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def callback(mut state: Token, var value: String, /, var **options: Int) -> Int:
    state.value += value.byte_length()
    return state.value

def main():
    var state = Token(1)
    var pending = Capture[Never].kwargs(state, "a", extra=1)
    var moved = state^
    _ = pending^.run(callback)
    _ = moved^
