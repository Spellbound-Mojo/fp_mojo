"""Local diagnostic timings; raw samples are separate from correctness soaks."""
from std.time import perf_counter_ns
from fp.algebra import tail_rec_m
from fp.callables import Unary
from fp.data import ControlFlow, Continue, Break
from fp.effects import CancellationToken
from fp.effects.async_runtime import Async, Driver, Clock, Duration, Nursery, Sleep, pure, run, sleep
from support import check


def mix(value: Int) -> Int:
    return (value * 1664525 + 1013904223) & 268435455


@fieldwise_init
struct Iterate(Unary):
    var limit: Int
    comptime Arg = Tuple[Int, Int]
    comptime Out = Async[Int].Pure[ControlFlow[Int, Self.Arg]]
    def call(self, var value: Self.Arg) -> Self.Out:
        if value[0] == self.limit:
            return pure[Int](ControlFlow[Int, Self.Arg](Break(value[1])))
        return pure[Int](ControlFlow[Int, Self.Arg](Continue((value[0] + 1, mix(value[1])))))


@no_inline
def sequence[library: Bool](count: Int, seed: Int) -> Int:
    comptime if library:
        var initial: Tuple[Int, Int] = (0, seed)
        var outcome = run(tail_rec_m[Async[Int]](Iterate(count), initial^))
        return outcome.take()._take_ok()
    else:
        var value = seed
        for _ in range(count):
            value = mix(value)
        return value


def timed[library: Bool](count: Int, seed: Int) -> Tuple[Int, Int]:
    var start = perf_counter_ns()
    var value = sequence[library](count, seed)
    return (Int(perf_counter_ns() - start), value)


def sequences(count: Int):
    check(sequence[True](count, 7) == sequence[False](count, 7), "warmup checksums agree")
    for index in range(9):
        var native: Tuple[Int, Int]
        var library: Tuple[Int, Int]
        if index % 2:
            library = timed[True](count, 17 + index)
            native = timed[False](count, 17 + index)
        else:
            native = timed[False](count, 17 + index)
            library = timed[True](count, 17 + index)
        check(native[1] == library[1], "native and typed loop perform identical arithmetic")
        print("sample sequence", "size=" + String(count), "index=" + String(index),
              "native_ns=" + String(native[0]), "async_ns=" + String(library[0]),
              "checksum=" + String(library[1]), flush=True)


def idle(count: Int) raises:
    for index in range(10):
        var clock = Clock.manual()
        var nursery = Nursery[Sleep[Int]](count)
        var spawn = nursery.spawner()
        for _ in range(count):
            check(not spawn.try_spawn(sleep[Int](Duration.seconds(1))), "bounded child admission")
        spawn.close()
        var driver = Driver(nursery^, CancellationToken(), clock)
        var parked = driver.poll()
        while parked.runnable:
            parked = driver.poll()
        check(not parked.completed and not parked.runnable, "nursery parked before measurement")
        var start = perf_counter_ns()
        var polls = 0
        for _ in range(10000):
            var progress = driver.poll()
            polls += progress.polls + progress.timers
        var elapsed = Int(perf_counter_ns() - start)
        check(polls == 0, "idle driving never scans or polls children")
        start = perf_counter_ns()
        driver.request_cancel()
        while not driver.poll().completed:
            pass
        check(not driver^.finish(), "cancellation joins every child")
        var canceled = Int(perf_counter_ns() - start)
        if index > 0:
            print("sample idle", "size=" + String(count), "index=" + String(index - 1),
                  "idle_ns=" + String(elapsed), "cancel_ns=" + String(canceled),
                  "calls=10000", "polls=0", flush=True)


def main() raises:
    sequences(1024)
    sequences(8192)
    sequences(65536)
    idle(1)
    idle(64)
    idle(512)
