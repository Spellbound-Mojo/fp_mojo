# error: no matching method
# error: value passed to 'function' cannot be converted
from fp._argument_staged import Capture

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    return state

def main():
    var state = 0
    _ = Capture[Never].kwargs(state, "a", extra="wrong").run(callback)
