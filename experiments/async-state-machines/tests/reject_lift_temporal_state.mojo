# error: constraint failed: sleep: mismatched base family, or a layer whose programs are not base programs
from fp.effects import StateT, LiftTemporal, sleep
from fp.effects.async_runtime import Async, Duration


def main() raises:
    # StateT forwards only Defer, Raise and Timing.
    _ = sleep[LiftTemporal[StateT[Async[Int], Int], Async[Int]]](Duration.milliseconds(1))
