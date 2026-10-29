# error: no matching
from fp.effects import IO, scoped_io
def read(var value: String) -> IO[Int].Pure[Int]: return IO[Int].pure(value.byte_length())
def main():
    var pointer: def(var String) thin -> IO[Int].Pure[Int] = read
    _ = scoped_io(pointer)
