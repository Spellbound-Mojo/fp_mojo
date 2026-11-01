# error: use of uninitialized value 'fiber'
from fp.effects.async_runtime import IO, Fiber


def twice(var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
    _ = fiber^.join()
    return fiber^.join_with(IO[Int, Int].pure(0))


def main():
    _ = IO[Int, Int].pure(1).start()
