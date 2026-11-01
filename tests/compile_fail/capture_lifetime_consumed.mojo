# error: uninitialized value 'pending'
from fp.data import Capture

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    state += text.byte_length()
    return state

def main():
    var state = 0
    var pending = Capture[Never].mutable(state).take("a").kwargs(extra=1)
    _ = pending^.run(callback)
    _ = pending^.run(callback)
