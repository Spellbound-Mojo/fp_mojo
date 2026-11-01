# error: no matching
from fp.effects import Reader, asks
def read(value: String) -> Int: return value.byte_length()
def main():
    var pointer: def(String) thin -> Int = read
    _ = asks[Reader[Int]](pointer)
