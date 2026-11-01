"""Run blocking calls off the fibers' threads, interruptibly, or on a pool of one."""
from std.time import sleep
from fp.effects import Interruption, Outcome
from fp.effects.async_runtime import IO, BlockingPool, Duration, IORuntimeConfig, run


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    return outcome.take()._take_ok()


def slow_read() -> Int:
    # Stands in for a blocking system call; other fibers keep running meanwhile.
    sleep(0.01)
    return 42


def wait_for_a_minute(interruption: Interruption) -> Int:
    # The wait returns False as soon as the fiber's cancellation is requested.
    try:
        if interruption.sleep(Duration.seconds(60)):
            return 1
    except:
        pass
    return 0


def add_pair(var pair: Tuple[Int, Int]) -> Int:
    return pair[0] + pair[1]


def main() raises:
    print("blocking:", value(run(IO[Int, Int].blocking(slow_read))))

    # A timeout cancels the call through its Interruption handle; the late
    # result is discarded and the fallback wins.
    var interrupted = IO[Int, Int].interruptible(wait_for_a_minute).timeout_to(
        Duration.milliseconds(20), IO[Int, Int].pure(-1))
    print("interrupted:", value(run(interrupted^)))

    # A configured pool is honored on every profile: one worker runs one call at a time.
    var config = IORuntimeConfig()
    config.blocking_pool = Optional(BlockingPool(1, Duration.seconds(5)))
    var two = IO[Int, Int].blocking(slow_read).both(IO[Int, Int].blocking(slow_read)).map(add_pair)
    print("one at a time:", value(run(two^, config)))
