# error: call to 'delay'
from fp.effects.async_runtime import IO


def wrong() raises String -> Int:
    raise String("not the selected error")


def main():
    var pointer: def() raises String thin -> Int = wrong
    _ = IO[Int, Int].delay(pointer)
