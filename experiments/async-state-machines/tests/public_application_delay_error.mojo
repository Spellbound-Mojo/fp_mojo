# error: call to 'delay'
from fp.effects.async_runtime import delay


def wrong() raises String -> Int:
    raise String("not the selected error")


def main():
    var pointer: def() raises String thin -> Int = wrong
    _ = delay[Int](pointer)
