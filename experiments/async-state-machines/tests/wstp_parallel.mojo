"""CPU-bound fibers run in parallel on the work-stealing pool and speed up with more workers.

A root starts `FIBERS` fibers, each a chain of `STEPS` binds whose callbacks
spin on arithmetic, then joins them all. The same program runs on pools of 1,
2 and 4 workers through the private entry point (`_run_pooled`), best of
`TRIALS` each. Checks:

- every fiber's result is right on every pool;
- on one worker no two steps ever overlap, and on more workers some do (an
  atomic count of steps in progress records its high-water mark), which shows
  fibers running in parallel without relying on timing;
- two and four workers finish faster than one, with a margin wide enough for
  a second qualification job on the same machine;
- the two sides of a `both` on a two-worker pool, each a single step that
  waits up to `MEET_NS` for the other to start, overlap: the first side,
  displaced from the LIFO slot by the second, reaches the other worker
  instead of waiting out the second side's run.

Timings go to standard error, so the expected output stays fixed.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import stderr
from std.time import perf_counter_ns
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig
from fp.effects._async.pool import _run_pooled

comptime FIBERS = 16
comptime STEPS = 40
comptime SPIN = 40_000
comptime TRIALS = 3
comptime MEET_NS = 2_000_000_000


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


struct Gauge(Movable):
    """Steps in progress and their high-water mark, in their own allocation."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.words = unsafe_alloc[Atomic[Int]](2)
        self.words.unsafe_offset(0).unsafe_write(Atomic(0))
        self.words.unsafe_offset(1).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        self.words.unsafe_offset(0).unsafe_deinit_pointee()
        self.words.unsafe_offset(1).unsafe_deinit_pointee()
        self.words.unsafe_free()

    def enter(self):
        var now = self.words[unsafe_offset=0].fetch_add[ordering=Ordering.ACQUIRE_RELEASE](1) + 1
        var high = self.words[unsafe_offset=1].load[ordering=Ordering.RELAXED]()
        while now > high:
            if self.words[unsafe_offset=1].compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](high, now):
                break

    def leave(self):
        _ = self.words[unsafe_offset=0].fetch_sub[ordering=Ordering.ACQUIRE_RELEASE](1)

    def high(self) -> Int:
        return self.words[unsafe_offset=1].load[ordering=Ordering.ACQUIRE]()


def spin(seed: Int) -> Int:
    var x = UInt64(seed) * 0x9E3779B97F4A7C15 + 1
    for _ in range(SPIN):
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
    return Int(x & 0xFFFF)


def expected(fiber: Int) -> Int:
    var total = 0
    for step in range(STEPS):
        total += spin(fiber * 1000 + step)
    return total


@fieldwise_init
struct Step(OnceUnary):
    """One CPU-bound step of a fiber's chain, then the next."""
    var fiber: Int
    var step: Int
    var gauge: ArcPointer[Gauge]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.step == STEPS:
            return IO[Int, Int].pure(total)
        self.gauge[].enter()
        var value = spin(self.fiber * 1000 + self.step)
        self.gauge[].leave()
        return IO[Int, Int].pure(total + value).flat_map(Self(self.fiber, self.step + 1, self.gauge^))


def chain(fiber: Int, gauge: ArcPointer[Gauge]) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Step(fiber, 0, gauge.copy()))


@fieldwise_init
struct StartRest(OnceUnary):
    """Keep a started fiber, then start the next or join them all."""
    var next: Int
    var fibers: List[Fiber[Int, Int]]
    var gauge: ArcPointer[Gauge]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[List[Int], Int]:
        self.fibers.append(fiber^)
        if self.next == FIBERS:
            return join_all(self.fibers^, List[Int]())
        return chain(self.next, self.gauge).start().flat_map(Self(self.next + 1, self.fibers^, self.gauge^))


def join_all(var fibers: List[Fiber[Int, Int]], var results: List[Int]) -> IO[List[Int], Int]:
    """Join in start order; later fibers keep running while earlier ones are joined."""
    if not len(fibers):
        return IO[List[Int], Int].pure(results^)
    var first = fibers.pop(0)
    return first^.join().flat_map(Collect(fibers^, results^))


@fieldwise_init
struct Collect(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    var results: List[Int]
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[List[Int], Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "every fiber succeeds")
        self.results.append(outcome.take()._take_ok())
        return join_all(self.rest^, self.results^)


def program(gauge: ArcPointer[Gauge]) -> IO[List[Int], Int]:
    return chain(0, gauge).start().flat_map(StartRest(1, List[Fiber[Int, Int]](), gauge.copy()))


@fieldwise_init
struct Meet(OnceUnary):
    """One step that waits, up to `MEET_NS`, until the other side's step is in progress too."""
    var gauge: ArcPointer[Gauge]
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        self.gauge[].enter()
        var start = perf_counter_ns()
        while self.gauge[].high() < 2 and perf_counter_ns() - start < MEET_NS:
            pass
        self.gauge[].leave()
        return 1


def pair_overlaps() -> Bool:
    var gauge = ArcPointer(Gauge())
    var left = IO[NoneType, Int].pure(None).map(Meet(gauge.copy()))
    var right = IO[NoneType, Int].pure(None).map(Meet(gauge.copy()))
    var outcome = _run_pooled(left^.both(right^), CancellationToken(), IORuntimeConfig(), 2)
    check(Bool(outcome) and outcome.value().is_ok(), "the pair succeeds")
    return gauge[].high() == 2


def trial(workers: Int, mut high: Int) -> Int:
    var gauge = ArcPointer(Gauge())
    var start = perf_counter_ns()
    var outcome = _run_pooled(program(gauge), CancellationToken(), IORuntimeConfig(), workers)
    var elapsed = Int(perf_counter_ns() - start)
    check(Bool(outcome) and outcome.value().is_ok(), "the root succeeds")
    var results = outcome.take()._take_ok()
    check(len(results) == FIBERS, "every fiber was joined")
    for fiber in range(FIBERS):
        check(results[fiber] == expected(fiber), "each fiber computes its own chain")
    high = max(high, gauge[].high())
    return elapsed


def best(workers: Int, mut high: Int) -> Int:
    var fastest = Int.MAX
    for _ in range(TRIALS):
        fastest = min(fastest, trial(workers, high))
    return fastest


def main():
    var one_high = 0
    var two_high = 0
    var four_high = 0
    var one = best(1, one_high)
    var two = best(2, two_high)
    var four = best(4, four_high)
    print("wstp_parallel ms: 1 worker", one // 1_000_000, "2 workers", two // 1_000_000, "4 workers", four // 1_000_000,
          "speedup 2:", Float64(one) / Float64(two), "4:", Float64(one) / Float64(four),
          "overlap:", one_high, two_high, four_high, file=stderr)
    check(one_high == 1, "one worker never overlaps two steps")
    check(two_high > 1 and four_high > 1, "more workers run steps in parallel")
    check(Float64(two) < 0.85 * Float64(one), "two workers are faster than one")
    check(Float64(four) < 0.85 * Float64(one), "four workers are faster than one")
    check(pair_overlaps(), "the two sides of a both run in parallel")
    print("wstp_parallel: CPU-bound fibers run in parallel and speed up with 2 and 4 workers")
