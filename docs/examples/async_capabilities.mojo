"""Use the effect capabilities through their dictionaries: Spawn, Concurrent, Timing, Temporal."""
from fp.callables import OnceUnary
from fp.effects import (Outcome, get_ref, join, make_ref, real_time, sleep, start, timed, update_ref)
from fp.effects.async_runtime import IO, Async, Duration, Fiber, Ref, SystemTime, run

comptime A = Async[Int]


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The program's success value; a failure or cancellation aborts."""
    var success = outcome.take().to_optional()
    return success.take()


def bump(var count: Int) -> Int:
    return count + 1


@fieldwise_init
struct ReadAfter(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return get_ref[A, Int](self.cell)


@fieldwise_init
struct BumpThenRead(OnceUnary):
    """Concurrent: update a fresh cell, then read it."""
    comptime Arg = Ref[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Int, Int]:
        return update_ref[A](cell, bump).flat_map(ReadAfter(cell.copy()))


@fieldwise_init
struct JoinChild(OnceUnary):
    """Spawn: join the started child."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Outcome[Int, Int], Int]:
        return join[A, Int](fiber^)


def at_least_five_ms(var measured: Tuple[Duration, NoneType]) -> Bool:
    return measured[0].to_nanoseconds() >= 5_000_000


def after_2020(var now: SystemTime) -> Bool:
    return now.to_seconds() > 1_577_836_800


def main() raises:
    print("ref:", value(run(make_ref[A](41).flat_map(BumpThenRead()))))
    var joined = value(run(start[A](IO[Int, Int].pure(7)).flat_map(JoinChild())))
    print("joined:", value(joined^))
    print("timed sleep >= 5 ms:", value(run(timed[A](sleep[A](Duration.milliseconds(5))).map(at_least_five_ms))))
    print("wall clock after 2020:", value(run(real_time[A]().map(after_2020))))
