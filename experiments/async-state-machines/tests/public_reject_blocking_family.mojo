# error: no matching function in call to 'blocking'
from fp.effects import OptionalT, blocking
from fp.effects.async_runtime import Async


def six() -> Int:
    return 6


def main():
    # OptionalT is a family, not a Blocking dictionary: select LiftBlocking.
    _ = blocking[OptionalT[Async[Int]]](six)
