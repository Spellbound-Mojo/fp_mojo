"""Responsiveness on the build's default profile (build at -O3; not qualified).

Every case runs on one `Runtime(IORuntimeConfig())`, so the profile is the
build's default: build twice, with `-D FP_ASYNC_PROFILE=current_thread` and
`-D FP_ASYNC_PROFILE=work_stealing`, to measure both. Timer lateness, idle CPU
and the foreign round trip are `profile_compare`'s `sleep`, `idle` and `rtt`
cases; this probe adds what that probe does not measure:

- `cancel_busy`: a child spins through `flat_map` steps, two transitions
  each, counting them; once it has run 4,096 steps its owner records the count
  and the time, then `fiber.cancel()` returns. Reports the steps the child ran
  after the request (median, 90th percentile, maximum) and the wall time of the
  `cancel` (median, 90th percentile).
- `cancel_parked`: a child that has started and waits forever; the wall time
  of `fiber.cancel()`.
- `wake`: one-way latency of a foreign wake: an `IO.async_` registration that
  a resident OS thread completes after 2 ms, when the program has parked; from
  the thread's `monotonic()` stamp just before `complete` to the continuation's
  stamp. Median, 90th percentile and maximum.

Usage: `responsiveness [case]`; all cases by default. Each case prints its
profile and the 1-minute load average before it runs.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv
from std.time import monotonic, sleep
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import EffectFailure, Outcome, ThreadTransferable
from fp.effects.async_runtime import IO, Fiber, Completion, IORuntimeConfig, Runtime
from fp._internal.os import OSThread

comptime SAMPLES = 200
comptime WARM_STEPS = 4_096


def check(condition: Bool, message: String):
    if not condition:
        abort(String("responsiveness: ", message))


def ok(var outcome: Outcome[Int, Int]) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def percentile(var values: List[Int], numerator: Int, denominator: Int) -> Int:
    sort(values)
    return values[min(len(values) - 1, len(values) * numerator // denominator)]


def load_average() -> String:
    try:
        with open("/proc/loadavg", "r") as f:
            return String(f.read().split(" ")[0])
    except:
        return String("unknown")


# ===--- shared probe state ---=== #


struct Probe(Movable, ThreadTransferable):
    """Counters a child and its owner share; every access is atomic."""
    var steps: Atomic[Int]
    var started: Atomic[Int]
    var stamp: Atomic[Int]

    def __init__(out self):
        self.steps = Atomic(0)
        self.started = Atomic(0)
        self.stamp = Atomic(0)


comptime Shared = ArcPointer[Probe]


# ===--- cancel a busy child ---=== #


@fieldwise_init
struct Spin(OnceUnary):
    """One step: count it, then continue forever."""
    var probe: Shared
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        _ = self.probe[].steps.fetch_add[ordering=Ordering.RELAXED](1)
        return IO[NoneType, Int].pure(None).flat_map(Spin(self.probe^))


@fieldwise_init
struct Measured(Copyable):
    var steps: Int
    var nanoseconds: Int


@fieldwise_init
struct Report(OnceUnary):
    """After `cancel` returns: steps run since the request, and its wall time."""
    var probe: Shared
    var steps: Int
    var start: Int
    var out: ArcPointer[List[Measured]]
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        var elapsed = Int(monotonic()) - self.start
        var after = self.probe[].steps.load[ordering=Ordering.ACQUIRE]() - self.steps
        self.out[].append(Measured(after, elapsed))
        return 0


@fieldwise_init
struct CancelWhenWarm(OnceUnary):
    """Cede until the child has started (and, when busy, run its warm-up steps), then cancel."""
    var fiber: Fiber[NoneType, Int]
    var probe: Shared
    var busy: Bool
    var out: ArcPointer[List[Measured]]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var ready = (self.probe[].steps.load[ordering=Ordering.ACQUIRE]() >= WARM_STEPS if self.busy
                     else self.probe[].started.load[ordering=Ordering.ACQUIRE]() == 1)
        if not ready:
            return IO[NoneType, Int].cede().flat_map(Self(self.fiber^, self.probe^, self.busy, self.out^))
        var steps = self.probe[].steps.load[ordering=Ordering.ACQUIRE]()
        var start = Int(monotonic())
        var cancel = self.fiber.cancel()
        _ = self.fiber^
        return cancel^.map(Report(self.probe^, steps, start, self.out^))


@fieldwise_init
struct Started(OnceUnary):
    var probe: Shared
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        self.probe[].started.store[ordering=Ordering.RELEASE](1)
        return IO[NoneType, Int].never()


@fieldwise_init
struct Owner(OnceUnary):
    var probe: Shared
    var busy: Bool
    var out: ArcPointer[List[Measured]]
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Int, Int]:
        return IO[NoneType, Int].cede().flat_map(CancelWhenWarm(fiber^, self.probe^, self.busy, self.out^))


def cancel_case(runtime: Runtime, busy: Bool):
    var out = ArcPointer(List[Measured]())
    for _ in range(SAMPLES):
        var probe = Shared(Probe())
        var child: IO[NoneType, Int]
        if busy:
            child = IO[NoneType, Int].pure(None).flat_map(Spin(probe.copy()))
        else:
            child = IO[NoneType, Int].pure(None).flat_map(Started(probe.copy()))
        _ = ok(runtime.run(child^.start().flat_map(Owner(probe^, busy, out.copy()))))
    var steps = List[Int]()
    var walls = List[Int]()
    for m in out[]:
        steps.append(m.steps)
        walls.append(m.nanoseconds)
    if busy:
        print("cancel_busy steps after request (2 transitions each): median", percentile(steps.copy(), 1, 2),
              "p90", percentile(steps.copy(), 9, 10), "max", percentile(steps^, 1, 1))
    print("cancel_busy" if busy else "cancel_parked", "wall us: median", Float64(percentile(walls.copy(), 1, 2)) / 1000.0,
          "p90", Float64(percentile(walls.copy(), 9, 10)) / 1000.0, "max", Float64(percentile(walls^, 1, 1)) / 1000.0)


# ===--- one-way foreign wake ---=== #


struct Mail(Movable):
    """One registration at a time for the resident completer, and its stop flag."""
    var lock: Pointer[Atomic[Int], MutUntrackedOrigin]
    var item: Pointer[Optional[Completion[Int, Int]], MutUntrackedOrigin]
    var stop: Pointer[Atomic[Int], MutUntrackedOrigin]
    var stamp: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.lock = unsafe_alloc[Atomic[Int]](1)
        self.lock.unsafe_write(Atomic(0))
        self.item = unsafe_alloc[Optional[Completion[Int, Int]]](1)
        self.item.unsafe_write(None)
        self.stop = unsafe_alloc[Atomic[Int]](1)
        self.stop.unsafe_write(Atomic(0))
        self.stamp = unsafe_alloc[Atomic[Int]](1)
        self.stamp.unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        self.item.unsafe_deinit_pointee()
        self.item.unsafe_free()
        self.lock.unsafe_deinit_pointee()
        self.lock.unsafe_free()
        self.stop.unsafe_deinit_pointee()
        self.stop.unsafe_free()
        self.stamp.unsafe_deinit_pointee()
        self.stamp.unsafe_free()

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


def complete_late(state: Pointer[Completer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    while state[].mail[].stop[].load[ordering=Ordering.ACQUIRE]() == 0:
        var item = state[].mail[].take()
        if item:
            sleep(0.002)  # long enough for the program, and the pool, to park
            state[].mail[].stamp[].store[ordering=Ordering.RELEASE](Int(monotonic()))
            _ = item.value().complete(Optional(Result[Int, EffectFailure[Int]](Ok(1))))
        else:
            sleep(0.0)
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
struct Woken(OnceUnary):
    var mail: ArcPointer[Mail]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return Int(monotonic()) - self.mail[].stamp[].load[ordering=Ordering.ACQUIRE]()


def wake_case(runtime: Runtime):
    var mail = ArcPointer(Mail())
    var thread: OSThread[Completer]
    try:
        thread = OSThread[Completer](ArcPointer(Completer(mail)), complete_late)
    except:
        abort("responsiveness: could not start the completer")
    var walls = List[Int]()
    for _ in range(SAMPLES):
        walls.append(ok(runtime.run(IO[Int, Int].async_(Post(mail.copy())).map(Woken(mail.copy())))))
    mail[].stop[].store[ordering=Ordering.RELEASE](1)
    _ = thread^
    print("wake one-way us: median", Float64(percentile(walls.copy(), 1, 2)) / 1000.0,
          "p90", Float64(percentile(walls.copy(), 9, 10)) / 1000.0, "max", Float64(percentile(walls^, 1, 1)) / 1000.0)


def main():
    var selected = String(argv()[1]) if len(argv()) > 1 else String("all")
    var settings = IORuntimeConfig()
    print("profile:", settings.profile, "| load average:", load_average())
    var runtime: Runtime
    try:
        runtime = Runtime(settings)
    except:
        abort("responsiveness: could not start the runtime")
    if selected == "all" or selected == "cancel_busy":
        cancel_case(runtime, True)
    if selected == "all" or selected == "cancel_parked":
        cancel_case(runtime, False)
    if selected == "all" or selected == "wake":
        wake_case(runtime)
    print("load average after:", load_average())
