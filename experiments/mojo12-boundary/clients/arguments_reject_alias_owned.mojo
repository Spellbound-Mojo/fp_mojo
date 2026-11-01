# error: aliasing values passed mutably to 'first' argument and passed mutably to 'second' argument in 'kwargs' call
from fp._argument_staged import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def callback(mut state: Token, var value: Token, /, var **options: Int) -> Int:
    state.value += value.value
    return state.value

def main():
    var state = Token(1)
    _ = Capture[Never].kwargs(state, state^, extra=1).run(callback)
