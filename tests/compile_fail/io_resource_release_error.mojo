# error: violated constraint
from fp.effects import IO, resource_io
from fp.algebra import pure

def release(var value: Int) -> IO[String].Pure[Int]:
    return pure[IO[String]](value)

def main():
    _ = resource_io(pure[IO[Int]](1), release)
