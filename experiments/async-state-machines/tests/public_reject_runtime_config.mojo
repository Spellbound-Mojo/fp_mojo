# error: no matching method in call to 'run'
from fp.effects.async_runtime import IO, IORuntimeConfig, Runtime


def main() raises:
    # The configuration belongs to the runtime; its run takes only a program and a token.
    var runtime = Runtime()
    _ = runtime.run(IO[Int, Int].pure(1), IORuntimeConfig())
