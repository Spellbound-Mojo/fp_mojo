# error: mutable reference argument 'first'cannot bind to temporary value
from fp._argument_staged import Capture

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    state += 1
    return state

def check(state: Int):
    _ = Capture[Never].kwargs(state, "a", extra=1).run(callback)

def main():
    check(1)
