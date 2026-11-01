# error: no matching
from fp.effects import Reader, scoped_io
def read(value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value)
def main():
    var pointer: def(Int) thin -> Reader[Int].Pure[Int] = read
    _ = scoped_io(pointer)
