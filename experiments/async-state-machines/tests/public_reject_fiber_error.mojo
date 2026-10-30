# error: no matching method in call to 'flat_map'
from fp.effects.async_runtime import IO, Fiber


def start_other(var value: Int) -> IO[Fiber[String, String], String]:
    return IO[String, String].pure(String(value)).start()


def main():
    _ = IO[Int, Int].pure(1).flat_map(start_other)
