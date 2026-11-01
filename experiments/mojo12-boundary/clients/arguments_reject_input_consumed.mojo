# error: uninitialized value 'payload'
from fp._argument_staged import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var state = 0
    var payload = Token(3)
    var pending = Capture[Never].kwargs(state, payload^, extra=1)
    print(payload.value)
    _ = pending^
