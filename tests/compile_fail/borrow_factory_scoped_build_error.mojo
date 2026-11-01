# error: no matching
from fp.effects import IO, scoped_io
def read(value: Int) raises String -> IO[Int].Pure[Int]: raise String("wrong")
def main():
    var pointer: def(Int) raises String thin -> IO[Int].Pure[Int] = read
    _ = scoped_io(pointer)
