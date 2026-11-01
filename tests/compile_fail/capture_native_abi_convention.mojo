# error: no matching method
from fp.data import Capture
def f(mut value: Int) -> Int:
    value += 1
    return value
def main():
    var pointer: def(mut Int) thin -> Int = f
    var value = 1
    _ = Capture.borrow(value).run(pointer)
