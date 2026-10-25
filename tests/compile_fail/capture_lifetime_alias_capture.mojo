# error: aliasing values passed mutably to 'self' argument and passed mutably to 'function' argument in 'run' call
from fp.data import Capture

def main():
    var state = 0
    def callback(mut first: Int, var text: String, /, var **options: Int) {mut state} -> Int:
        state += 1
        first += text.byte_length()
        return first
    var pending = Capture[Never].mutable(state).take("a").kwargs(extra=1)
    _ = pending^.run(callback)
