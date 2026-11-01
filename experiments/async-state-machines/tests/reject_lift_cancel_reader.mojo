# error: constraint failed: canceled: mismatched base family, or a layer whose programs are not base programs
from fp.effects import ReaderT, LiftCancel, canceled
from fp.effects.async_runtime import Async


def main():
    # ReaderT programs are reader actions, not base programs: Cancel does not forward.
    _ = canceled[LiftCancel[ReaderT[Async[Int], Int], Async[Int]]]()
