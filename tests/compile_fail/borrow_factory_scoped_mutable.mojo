# error: no matching
from fp.effects import IO, scoped_io
def read(mut value: Int) -> IO[Int].Pure[Int]:
    value += 1
    return IO[Int].pure(value)
def main():
    var pointer: def(mut Int) thin -> IO[Int].Pure[Int] = read
    _ = scoped_io(pointer)
