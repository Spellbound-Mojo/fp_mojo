# error: no matching
from fp.effects import Reader, asks
def read(mut value: Int) -> Int:
    value += 1
    return value
def main():
    var pointer: def(mut Int) thin -> Int = read
    _ = asks[Reader[Int]](pointer)
