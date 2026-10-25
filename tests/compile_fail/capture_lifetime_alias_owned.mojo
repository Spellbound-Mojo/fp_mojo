# error: aliasing values passed mutably to 'self' argument and passed mutably to 'value' argument in 'take' call
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def callback(mut state: Token, var value: Token, /, var **options: Int) -> Int:
    state.value += value.value
    return state.value

def main():
    var state = Token(1)
    _ = Capture[Never].mutable(state).take(state^).kwargs(extra=1).run(callback)
