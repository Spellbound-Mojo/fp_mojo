# error: value has no attribute 'park'
from fp.effects.async_runtime import IO, TestControl


def main() raises:
    # Virtual time never parks: TestControl has no park, only ticks and advances.
    var control = TestControl(IO[Int, Int].pure(1))
    control.park()
    control.tick()
    _ = control^.results()
