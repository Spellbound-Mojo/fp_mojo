# error: failed to infer parameter 'K'
from fp._argument_staged import Capture

def callback(var state: Int, /, var **options: Int) -> Int:
    return state

def main():
    var state = 0
    _ = Capture[Never].kwargs(state, "a").run(callback)
