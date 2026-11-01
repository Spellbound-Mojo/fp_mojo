"""CPU-bound fibers that cede often keep their parallel speedup on the pool (build at -O3; not qualified).

A root starts `fibers` fibers (2 or 4), each running rounds of a CPU spin
followed by `IO.cede()`, then joins them all. Each spin length gives runs of
roughly 2, 10 and 50 µs between cedes, with the rounds scaled so every fiber
does about the same total work. The same program runs on pools of 1, 2 and 4
workers through the private entry point (`_run_pooled`).

Each line prints the median wall time in milliseconds over `TRIALS` trials,
the range in brackets, and the speedup of the medians against one worker.
The probe guards the delayed notify on a ceding requeue: a lazy notify must
not keep such fibers on one core while other workers park.

The long-sibling case: a fiber that cedes `CEDES` times with almost no work
in between starts beside a sibling whose single step spins for 1 or 5 ms
without ceding. The ceder runs first on the worker that started both, so each
of its cedes requeues it behind the sibling. The line prints the median over
`LATENCY_TRIALS` of the ceder's latency, from its first step to its last, on
pools of 2 and 4 workers: the delayed notify may hold the ceder behind the
sibling's run.

Usage: `cede_fanout [fanout|sibling]`; both by default. Compare only runs taken back to back on a quiet host.
"""
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig
from fp.effects._async.pool import _run_pooled

comptime TRIALS = 6
comptime WORK = 40_000_000
"""Spin iterations per fiber, split into rounds."""


def check(condition: Bool, message: String):
    if not condition:
        abort(String("cede_fanout: ", message))


def spin(seed: Int, count: Int) -> Int:
    var x = UInt64(seed) * 0x9E3779B97F4A7C15 + 1
    for _ in range(count):
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
    return Int(x & 0xFFFF)


@fieldwise_init
struct Round(OnceUnary):
    """Spin once, cede, then the next round, or the fiber's total."""
    var fiber: Int
    var left: Int
    var total: Int
    var count: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(self.total)
        var value = spin(self.fiber * 1_000_003 + self.left, self.count)
        return IO[NoneType, Int].cede().flat_map(Self(self.fiber, self.left - 1, self.total + value, self.count))


def worker_fiber(fiber: Int, rounds: Int, count: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].cede().flat_map(Round(fiber, rounds, 0, count))


@fieldwise_init
struct StartRest(OnceUnary):
    var next: Int
    var fibers: Int
    var rounds: Int
    var count: Int
    var started: List[Fiber[Int, Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.started.append(fiber^)
        if self.next == self.fibers:
            return join_all(self.started^, 0)
        return worker_fiber(self.next, self.rounds, self.count).start().flat_map(Self(self.next + 1, self.fibers, self.rounds, self.count, self.started^))


def join_all(var fibers: List[Fiber[Int, Int]], total: Int) -> IO[Int, Int]:
    if not len(fibers):
        return IO[Int, Int].pure(total)
    var first = fibers.pop(0)
    return first^.join().flat_map(Collect(fibers^, total))


@fieldwise_init
struct Collect(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "every fiber succeeds")
        return join_all(self.rest^, self.total + outcome.take()._take_ok())


def expected(fibers: Int, rounds: Int, count: Int) -> Int:
    var total = 0
    for fiber in range(fibers):
        for left in range(rounds, 0, -1):
            total += spin(fiber * 1_000_003 + left, count)
    return total


def trial(fibers: Int, rounds: Int, count: Int, workers: Int, want: Int) -> Float64:
    var program = worker_fiber(0, rounds, count).start().flat_map(StartRest(1, fibers, rounds, count, List[Fiber[Int, Int]]()))
    var start = perf_counter_ns()
    var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), workers)
    var elapsed = Float64(perf_counter_ns() - start) / 1_000_000.0
    check(Bool(outcome) and outcome.value().is_ok(), "the root succeeds")
    check(outcome.take()._take_ok() == want, "every fiber's sum is right")
    return elapsed


def median(var values: List[Float64]) -> Float64:
    sort(values)
    var n = len(values)
    return values[n // 2] if n % 2 else (values[n // 2 - 1] + values[n // 2]) / 2.0


def unit() -> IO[NoneType, Int]:
    var value: NoneType = None
    return IO[NoneType, Int].pure(value)


comptime CEDES = 20
comptime LATENCY_TRIALS = 21


@fieldwise_init
struct Ceder(OnceUnary):
    """Cede `left` more times, then the nanoseconds since `began`."""
    var left: Int
    var began: UInt
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var began = self.began if self.began else UInt(perf_counter_ns())
        if self.left == 0:
            return IO[Int, Int].pure(Int(UInt(perf_counter_ns()) - began))
        return IO[NoneType, Int].cede().flat_map(Self(self.left - 1, began))


@fieldwise_init
struct Long(OnceUnary):
    var count: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].pure(spin(7, self.count))


@fieldwise_init
struct StartCeder(OnceUnary):
    var long: Fiber[Int, Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ceder: Fiber[Int, Int]) -> IO[Int, Int]:
        return ceder^.join().flat_map(JoinLong(self.long^))


@fieldwise_init
struct JoinLong(OnceUnary):
    var long: Fiber[Int, Int]
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "the ceder succeeds")
        return self.long^.join().map(Keep(outcome.take()._take_ok()))


@fieldwise_init
struct Keep(OnceUnary):
    var latency: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        check(Bool(outcome) and outcome.value().is_ok(), "the long sibling succeeds")
        return self.latency


@fieldwise_init
struct StartLong(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var long: Fiber[Int, Int]) -> IO[Int, Int]:
        var ceder = unit().flat_map(Ceder(CEDES, 0))
        return ceder^.start().flat_map(StartCeder(long^))


def sibling(count: Int, workers: Int) -> Float64:
    var long = unit().flat_map(Long(count))
    var program = long^.start().flat_map(StartLong())
    var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), workers)
    check(Bool(outcome) and outcome.value().is_ok(), "the root succeeds")
    return Float64(outcome.take()._take_ok()) / 1_000.0


def siblings():
    var t0 = perf_counter_ns()
    var sink = spin(3, 1_000_000)
    var per_ms = Int(1_000_000.0 / (Float64(perf_counter_ns() - t0) / 1_000_000.0))
    for ms in [1, 5]:
        var line = String("sibling ", ms, " ms (sink ", sink % 2, "): ceder latency us over ", CEDES, " cedes")
        for workers in [2, 4]:
            var samples = List[Float64]()
            for _ in range(LATENCY_TRIALS):
                samples.append(sibling(per_ms * ms, workers))
            sort(samples)
            line += String(" | w", workers, " median ", Float64(Int(median(samples.copy()) * 10)) / 10.0, " [", Float64(Int(samples[0] * 10)) / 10.0, "..", Float64(Int(samples[len(samples) - 1] * 10)) / 10.0, "]")
        print(line)


def main():
    var selected = String(argv()[1]) if len(argv()) > 1 else String("all")
    if selected == "all" or selected == "sibling":
        siblings()
    if selected == "all" or selected == "fanout":
        fanout()


def fanout():
    for count in [2_000, 10_000, 50_000]:
        # Time one spin, for the run length between cedes.
        var t0 = perf_counter_ns()
        var sink = 0
        for i in range(200):
            sink += spin(i, count)
        var run_us = Float64(perf_counter_ns() - t0) / 200.0 / 1_000.0
        var rounds = WORK // count
        for fibers in [2, 4]:
            var want = expected(fibers, rounds, count)
            var one: Float64 = 0
            var line = String("spin ", count, " (~", Float64(Int(run_us * 10)) / 10.0, " us/run, sink ", sink % 2, ") fibers ", fibers, ":")
            for workers in [1, 2, 4]:
                var samples = List[Float64]()
                for _ in range(TRIALS):
                    samples.append(trial(fibers, rounds, count, workers, want))
                sort(samples)
                var m = median(samples.copy())
                if workers == 1:
                    one = m
                line += String(" | w", workers, " ", Float64(Int(m * 100)) / 100.0, " ms [", Float64(Int(samples[0] * 100)) / 100.0, "..", Float64(Int(samples[len(samples) - 1] * 100)) / 100.0, "] x", Float64(Int(one / m * 100)) / 100.0)
            print(line)
