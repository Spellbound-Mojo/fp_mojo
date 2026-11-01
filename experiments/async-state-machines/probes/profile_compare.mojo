"""Throughput and latency on both profiles, from one binary (build at -O3; not qualified).

Every case runs through the public `run` with an explicit profile, so one
build measures the current-thread profile and a four-worker work-stealing
pool back to back, and the same file builds against `nightly` for the
performance gates. Each case prints the median of `ROUNDS` round medians with
the range of round medians in brackets, per operation:

- `run`: a trivial `run(IO.pure(i))`, per run (a per-call pool on the pool).
- `pair`, `pair_yield`: start two children that finish at once (or cede once
  each first) and join both, per pair.
- `join`: start a child that finishes at once and join it, so the join races
  the child's completion, per join.
- `rtt`: an `IO.async` registration completed by a resident OS thread, through
  to its continuation, per round trip.
- `starts`: start 1,000 fibers that wait forever, then finish, so the scope
  cancels and drains them, per fiber.
- `step`: a chain of `flat_map` steps over pure values, per step.
- `both`, `race`: `both` and `race` of two pure sides, per call.
- `par`: `par_traverse` over 1,000 elements that cede once, per element.
- `sleep`: lateness of 1 ms sleeps, median and 90th percentile, in microseconds.
- `idle`: process CPU used by a `run` that sleeps 2 s, in microseconds.

Usage: `profile_compare [case]`; all cases by default. Compare only runs taken
back to back on a quiet host.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv
from std.time import monotonic, perf_counter_ns, sleep
from fp.algebra import par_traverse
from fp.callables import OnceUnary, Unary
from fp.data import Result, Ok
from fp.effects import EffectFailure, Outcome
from fp.effects.async_runtime import IO, Fiber, Completion, Duration, IORuntimeConfig, Profile, RaceResult, run
from fp._internal.os import OSThread, getrusage, RUSAGE_SELF

comptime ROUNDS = 6
comptime WORKERS = 4


def check(condition: Bool, message: String):
    if not condition:
        abort(String("profile_compare: ", message))


def config(pooled: Bool) -> IORuntimeConfig:
    var settings = IORuntimeConfig()
    if pooled:
        try:
            settings.profile = Profile.work_stealing(WORKERS)
        except:
            abort("profile_compare: a valid worker count")
    else:
        settings.profile = Profile.current_thread()
    return settings^


def median(var values: List[Float64]) -> Float64:
    sort(values)
    return values[len(values) // 2]


def summary(var rounds: List[Float64]) -> String:
    sort(rounds)
    return String(median(rounds.copy()), " [", rounds[0], "-", rounds[len(rounds) - 1], "]")


def ok(var outcome: Outcome[Int, Int]) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


# ===--- run ---=== #


def trivial(pooled: Bool) -> Float64:
    comptime count = 2_000
    var settings = config(pooled)
    var start = perf_counter_ns()
    for i in range(count):
        _ = ok(run(IO[Int, Int].pure(i), settings))
    return Float64(perf_counter_ns() - start) / Float64(count)


# ===--- pair and join ---=== #


def child(value: Int, yields: Bool) -> IO[Int, Int]:
    if yields:
        return IO[NoneType, Int].cede().map(Const(value))
    return IO[Int, Int].pure(value)


@fieldwise_init
struct SecondChild(OnceUnary):
    var yields: Bool
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Fiber[Int, Int]) -> IO[Int, Int]:
        return child(2, self.yields).start().flat_map(JoinBoth(first^))


@fieldwise_init
struct JoinBoth(OnceUnary):
    var first: Fiber[Int, Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var second: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.first^.join().flat_map(JoinSecond(second^))


@fieldwise_init
struct JoinSecond(OnceUnary):
    var second: Fiber[Int, Int]
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Outcome[Int, Int]) -> IO[Int, Int]:
        return self.second^.join().map(Sum(ok(first^)))


@fieldwise_init
struct Sum(OnceUnary):
    var first: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var second: Outcome[Int, Int]) -> Int:
        return self.first + ok(second^)


@fieldwise_init
struct Pairs(OnceUnary):
    var left: Int
    var yields: Bool
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return child(1, self.yields).start().flat_map(SecondChild(self.yields)).map(Plus(total)).flat_map(Self(self.left - 1, self.yields))


def pairs(pooled: Bool, yields: Bool) -> Float64:
    comptime count = 20_000
    var start = perf_counter_ns()
    check(ok(run(IO[Int, Int].pure(0).flat_map(Pairs(count, yields)), config(pooled))) == 3 * count, "every pair sums both children")
    return Float64(perf_counter_ns() - start) / Float64(count)


@fieldwise_init
struct Joins(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].pure(1).start().flat_map(JoinOne()).map(Plus(total)).flat_map(Self(self.left - 1))


@fieldwise_init
struct JoinOne(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Unwrap())


@fieldwise_init
struct Unwrap(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return ok(outcome^)


def joins(pooled: Bool) -> Float64:
    comptime count = 20_000
    var start = perf_counter_ns()
    check(ok(run(IO[Int, Int].pure(0).flat_map(Joins(count)), config(pooled))) == count, "every join sees its child")
    return Float64(perf_counter_ns() - start) / Float64(count)


# ===--- foreign round trip ---=== #


struct Mail(Movable):
    """One registration at a time for the resident completer, and its stop flag."""
    var lock: Pointer[Atomic[Int], MutUntrackedOrigin]
    var item: Pointer[Optional[Completion[Int, Int]], MutUntrackedOrigin]
    var stop: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.lock = unsafe_alloc[Atomic[Int]](1)
        self.lock.unsafe_write(Atomic(0))
        self.item = unsafe_alloc[Optional[Completion[Int, Int]]](1)
        self.item.unsafe_write(None)
        self.stop = unsafe_alloc[Atomic[Int]](1)
        self.stop.unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        self.item.unsafe_deinit_pointee()
        self.item.unsafe_free()
        self.lock.unsafe_deinit_pointee()
        self.lock.unsafe_free()
        self.stop.unsafe_deinit_pointee()
        self.stop.unsafe_free()

    def _acquire(self):
        while True:
            var expected = 0
            if self.lock[].compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](expected, 1):
                return
            sleep(0.0)

    def put(self, var completion: Completion[Int, Int]):
        self._acquire()
        self.item[] = Optional(completion^)
        self.lock[].store[ordering=Ordering.RELEASE](0)

    def take(self) -> Optional[Completion[Int, Int]]:
        self._acquire()
        var taken = self.item[].take() if self.item[] else Optional[Completion[Int, Int]](None)
        self.lock[].store[ordering=Ordering.RELEASE](0)
        return taken^


struct Completer(Movable):
    var mail: ArcPointer[Mail]

    def __init__(out self, mail: ArcPointer[Mail]):
        self.mail = mail.copy()


def complete_mail(state: Pointer[Completer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    while state[].mail[].stop[].load[ordering=Ordering.ACQUIRE]() == 0:
        var item = state[].mail[].take()
        if item:
            _ = item.value().complete(Optional(Result[Int, EffectFailure[Int]](Ok(1))))
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


@fieldwise_init
struct Post(OnceUnary):
    var mail: ArcPointer[Mail]
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Int, Int]) -> NoneType:
        self.mail[].put(completion^)
        return None


@fieldwise_init
struct Trips(OnceUnary):
    var left: Int
    var mail: ArcPointer[Mail]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].async_(Post(self.mail.copy())).map(Plus(total)).flat_map(Self(self.left - 1, self.mail^))


def trips(pooled: Bool) -> Float64:
    comptime count = 10_000
    var mail = ArcPointer(Mail())
    var thread: OSThread[Completer]
    try:
        thread = OSThread[Completer](ArcPointer(Completer(mail)), complete_mail)
    except:
        abort("profile_compare: could not start the completer")
    var start = perf_counter_ns()
    check(ok(run(IO[Int, Int].pure(0).flat_map(Trips(count, mail.copy())), config(pooled))) == count, "every round trip completes")
    var elapsed = Float64(perf_counter_ns() - start) / Float64(count)
    mail[].stop[].store[ordering=Ordering.RELEASE](1)
    _ = thread^
    return elapsed


# ===--- starts under one scope ---=== #


@fieldwise_init
struct Starts(OnceUnary):
    var left: Int
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Int, Int]:
        _ = fiber^
        if self.left == 0:
            return IO[Int, Int].pure(1)
        return IO[NoneType, Int].never().start().flat_map(Self(self.left - 1))


def starts(pooled: Bool) -> Float64:
    comptime count = 1_000
    var start = perf_counter_ns()
    _ = ok(run(IO[NoneType, Int].never().start().flat_map(Starts(count - 1)), config(pooled)))
    return Float64(perf_counter_ns() - start) / Float64(count)


# ===--- steps, both, race ---=== #


@fieldwise_init
struct Steps(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].pure(total + 1).flat_map(Self(self.left - 1))


def steps(pooled: Bool) -> Float64:
    comptime count = 200_000
    var start = perf_counter_ns()
    check(ok(run(IO[Int, Int].pure(0).flat_map(Steps(count)), config(pooled))) == count, "every step ran")
    return Float64(perf_counter_ns() - start) / Float64(count)


@fieldwise_init
struct SumPair(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


@fieldwise_init
struct Won(OnceUnary):
    comptime Arg = RaceResult[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var result: RaceResult[Int, Int]) -> Int:
        return 1


@fieldwise_init
struct Pairwise(OnceUnary):
    var left: Int
    var racing: Bool
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        var next: IO[Int, Int]
        if self.racing:
            next = IO[Int, Int].pure(1).race(IO[Int, Int].pure(2)).map(Won())
        else:
            next = IO[Int, Int].pure(1).both(IO[Int, Int].pure(2)).map(SumPair())
        return next^.map(Plus(total)).flat_map(Self(self.left - 1, self.racing))


def pairwise(pooled: Bool, racing: Bool) -> Float64:
    comptime count = 20_000
    var start = perf_counter_ns()
    _ = ok(run(IO[Int, Int].pure(0).flat_map(Pairwise(count, racing)), config(pooled)))
    return Float64(perf_counter_ns() - start) / Float64(count)


# ===--- par_traverse ---=== #


@fieldwise_init
struct Element(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        return IO[NoneType, Int].cede().map(Const(index))


@fieldwise_init
struct Count(OnceUnary):
    comptime Arg = List[Int]
    comptime Out = Int

    def call_once(deinit self, var values: List[Int]) -> Int:
        return len(values)


def par(pooled: Bool) -> Float64:
    comptime count = 1_000
    var indices = List[Int](capacity=count)
    for i in range(count):
        indices.append(i)
    var start = perf_counter_ns()
    check(ok(run(par_traverse(indices^, Element()).map(Count()), config(pooled))) == count, "every element ran")
    return Float64(perf_counter_ns() - start) / Float64(count)


# ===--- latency and idle CPU ---=== #


@fieldwise_init
struct Lateness(OnceUnary):
    """Sleep 1 ms `left` more times, recording each sleep's lateness in microseconds."""
    var left: Int
    var late: ArcPointer[List[Float64]]
    var started: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.started:
            self.late[].append(Float64(Int(monotonic()) - self.started - 1_000_000) / 1_000.0)
        if self.left == 0:
            return IO[Int, Int].pure(0)
        var millisecond: Duration
        try:
            millisecond = Duration.milliseconds(1)
        except:
            abort("profile_compare: a valid duration")
        return IO[NoneType, Int].sleep(millisecond).flat_map(Self(self.left - 1, self.late.copy(), Int(monotonic())))


def lateness(pooled: Bool) -> Tuple[Float64, Float64]:
    var late = ArcPointer(List[Float64]())
    _ = ok(run(IO[NoneType, Int].pure(None).flat_map(Lateness(200, late.copy(), 0)), config(pooled)))
    var values = late[].copy()
    sort(values)
    return Tuple(values[len(values) // 2], values[len(values) * 9 // 10])


def cpu_ns() -> Int:
    try:
        var usage = getrusage(RUSAGE_SELF)
        return usage.user_nanoseconds + usage.system_nanoseconds
    except:
        abort("profile_compare: getrusage")


def idle(pooled: Bool) -> Float64:
    var two: Duration
    try:
        two = Duration.seconds(2)
    except:
        abort("profile_compare: a valid duration")
    var before = cpu_ns()
    _ = ok(run(IO[NoneType, Int].sleep(two).map(Const(0)), config(pooled)))
    return Float64(cpu_ns() - before) / 1_000.0


# ===--- main ---=== #


def measure(name: String, selected: String, kind: Int):
    if selected != "all" and selected != name:
        return
    var current = List[Float64]()
    var pool = List[Float64]()
    for _ in range(ROUNDS):
        for pooled in [False, True]:
            var samples = List[Float64]()
            for _ in range(3):
                var value: Float64
                if kind == 0:
                    value = trivial(pooled)
                elif kind == 1:
                    value = pairs(pooled, False)
                elif kind == 2:
                    value = pairs(pooled, True)
                elif kind == 3:
                    value = joins(pooled)
                elif kind == 4:
                    value = trips(pooled)
                elif kind == 5:
                    value = starts(pooled)
                elif kind == 6:
                    value = steps(pooled)
                elif kind == 7:
                    value = pairwise(pooled, False)
                elif kind == 8:
                    value = pairwise(pooled, True)
                else:
                    value = par(pooled)
                samples.append(value)
            if pooled:
                pool.append(median(samples^))
            else:
                current.append(median(samples^))
    print(name, "ns: current_thread", summary(current^), "| work_stealing(4)", summary(pool^))


def main():
    var selected = String(argv()[1]) if len(argv()) > 1 else String("all")
    measure("run", selected, 0)
    measure("pair", selected, 1)
    measure("pair_yield", selected, 2)
    measure("join", selected, 3)
    measure("rtt", selected, 4)
    measure("starts", selected, 5)
    measure("step", selected, 6)
    measure("both", selected, 7)
    measure("race", selected, 8)
    measure("par", selected, 9)
    if selected == "all" or selected == "sleep":
        for pooled in [False, True]:
            var result = lateness(pooled)
            print("sleep 1 ms lateness us:", "work_stealing(4)" if pooled else "current_thread", "median", result[0], "p90", result[1])
    if selected == "all" or selected == "idle":
        for pooled in [False, True]:
            var used = List[Float64]()
            for _ in range(5):
                used.append(idle(pooled))
            print("idle 2 s run, process CPU us:", "work_stealing(4)" if pooled else "current_thread", summary(used^))
