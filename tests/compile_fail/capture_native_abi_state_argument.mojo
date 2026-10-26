# error: cannot be converted
from fp.data import Capture
def f(mut value: Int, var text: String) -> Int:
    value += text.byte_length()
    return value
def main():
    var pointer: def(mut Int, var String) thin -> Int = f
    var state = Capture().stateful(pointer, 1)
    _ = state.run(2)
