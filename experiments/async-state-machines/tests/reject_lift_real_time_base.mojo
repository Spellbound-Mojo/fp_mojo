# error: constraint failed: real_time: mismatched base family
from fp.effects import OptionalT, LiftTiming, real_time
from fp.effects.async_runtime import Async


def main() raises:
    # The selected Timing must belong to the layer's immediate base.
    _ = real_time[LiftTiming[OptionalT[Async[Int]], Async[String]]]()
