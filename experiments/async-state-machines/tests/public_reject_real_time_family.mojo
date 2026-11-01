# error: 'real_time' parameter 'I' has 'Timing' type, but value has type 'AnyStruct[LiftConcurrent[_OptionalT[Async[Int]], Async[Int]]]'
from fp.effects import OptionalT, LiftConcurrent, real_time
from fp.effects.async_runtime import Async


def main() raises:
    # A family selected without Timing has no clock to read.
    _ = real_time[LiftConcurrent[OptionalT[Async[Int]], Async[Int]]]()
