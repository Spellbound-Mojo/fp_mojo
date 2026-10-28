# error: violated constraint
from fp.effects import IO, Poll, resource_io_full
from fp.algebra import pure

def acquire(var poll: Poll[String]) -> IO[Int].Pure[Int]:
    return pure[IO[Int]](1)

def release(var value: Int) -> IO[Int].Pure[Int]:
    return pure[IO[Int]](value)

def main():
    _ = resource_io_full[Int](acquire, release)
