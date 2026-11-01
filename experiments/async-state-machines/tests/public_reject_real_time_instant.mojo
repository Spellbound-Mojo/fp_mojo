# error: cannot implicitly convert 'IO[SystemTime, Int]' value to 'IO[Instant, Int]'
from fp.effects.async_runtime import IO, Instant


def main() raises:
    # A wall-clock reading is never a monotonic Instant.
    var reading: IO[Instant, Int] = IO[Instant, Int].real_time()
    _ = reading^
