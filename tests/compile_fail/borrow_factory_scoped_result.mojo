# error: no matching
from fp.effects import scoped_io
def read(value: Int) -> Int: return value
def main():
    var pointer: def(Int) thin -> Int = read
    _ = scoped_io(pointer)
