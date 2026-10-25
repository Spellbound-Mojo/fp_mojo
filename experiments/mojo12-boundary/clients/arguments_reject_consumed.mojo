# error: uninitialized value 'pending'
from fp._argument_staged import Capture

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    state += text.byte_length()
    return state

def main():
    var state = 0
    var pending = Capture[Never].kwargs(state, "a", extra=1)
    _ = pending^.run(callback)
    _ = pending^.run(callback)
