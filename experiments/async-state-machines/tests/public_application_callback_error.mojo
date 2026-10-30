# error: call to 'async'
from fp.effects.async_runtime import IO, Completion


def wrong(var completion: Completion[Int, Int]) raises String:
    raise String("not the selected error")


def main():
    _ = IO[Int, Int].async(wrong, IO[NoneType, Int].pure(NoneType()))
