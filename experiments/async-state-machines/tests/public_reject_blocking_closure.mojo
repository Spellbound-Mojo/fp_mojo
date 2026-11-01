# error: no matching function in call to 'blocking'
from fp.effects.async_runtime import IO


def main():
    # A blocking function moves to a worker thread, so a capturing closure is rejected.
    var base = 2
    def add() {base} -> Int:
        return base + 1
    _ = IO[Int, Int].blocking(add)
