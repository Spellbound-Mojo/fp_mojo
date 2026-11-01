"""`run` parks in the root's poller instead of sleeping on a timer.

- An idle `run` over a long sleep uses almost no CPU on its thread
  (`getrusage(RUSAGE_THREAD)`).
- Timers fire close to their deadlines.
- Wakes from OS threads, through an `IO.async` completion, a `Signal` a custom
  leaf waits on, and a cancellation, reach a root that is about to park or is
  parked: no wake is lost, under randomized delays on both sides. A watchdog
  thread aborts if a round outlives its bound, so a lost wake fails the client
  instead of hanging it.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, unsafe_start
from fp.effects import Fiber as Thread
from fp.effects import IO as SyncIO
from fp.effects.protocols import ReaderAction
from fp.effects.async_runtime import IO, Completion, Duration, run
from fp.effects.async_runtime.protocols import Machine, Step, Wait, Signal
from fp._internal.os import getrusage, RUSAGE_THREAD


comptime ROUNDS = 300
comptime ROUND_BOUND_NS = 2_000_000_000


def check(condition: Bool, message: String):
    if not condition:
        abort(String("run parks: ", message))


def spin(nanoseconds: Int):
    var end = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < end:
        pass


def thread_cpu() -> Int:
    try:
        return getrusage(RUSAGE_THREAD).total_nanoseconds()
    except:
        abort("run parks: getrusage failed")


struct Random(Movable):
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def below(mut self, bound: Int) -> Int:
        self.state = self.state * 6364136223846793005 + 1442695040888963407
        return Int((self.state >> 33) % UInt64(bound))


def idle_sleep() raises:
    """A one-second sleep parks once: almost no CPU on the polling thread."""
    var before = thread_cpu()
    var started = Int(monotonic())
    var outcome = run(IO[NoneType, Int].sleep(Duration.seconds(1)))
    var elapsed = Int(monotonic()) - started
    var used = thread_cpu() - before
    check(Bool(outcome) and outcome.value().is_ok(), "the sleep completes")
    check(elapsed >= 1_000_000_000, "the sleep lasts its duration")
    # A 1 ms idle loop wakes a thousand times here; parking wakes about once.
    check(used < 5_000_000, String("an idle run used ", used, " ns of CPU"))
    print("idle: a one-second sleep used under 5 ms of thread CPU")


def timers():
    """Sleeps end close to their deadlines: a park waits until the deadline, not in 1 ms slices."""
    var lateness = List[Int]()
    for i in range(20):
        var requested = 2_000_000 + i * 250_000
        var duration = Duration()
        duration._nanoseconds = requested
        var started = Int(monotonic())
        var outcome = run(IO[NoneType, Int].sleep(duration))
        var elapsed = Int(monotonic()) - started
        check(Bool(outcome) and outcome.value().is_ok(), "each sleep completes")
        check(elapsed >= requested, "no timer fires early")
        lateness.append(elapsed - requested)
    sort(lateness)
    # A shared host can delay any one wake; the median shows the mechanism.
    check(lateness[len(lateness) // 2] < 1_000_000, String("median lateness ", lateness[len(lateness) // 2], " ns"))
    print("timers: no sleep ends early, and the median one ends within 1 ms of its deadline")


# ===------------------------------------------------------------------=== #
# Foreign wakes
# ===------------------------------------------------------------------=== #


struct Watchdog(ReaderAction):
    """Abort when the round counter stops moving for longer than a round's bound."""
    var round: ArcPointer[Atomic[Int]]
    var done: ArcPointer[Atomic[UInt8]]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def __init__(out self, round: ArcPointer[Atomic[Int]], done: ArcPointer[Atomic[UInt8]]):
        self.round = round.copy()
        self.done = done.copy()

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        var seen = self.round[].load()
        var since = Int(monotonic())
        while self.done[].load() == 0:
            spin(1_000_000)
            var now = self.round[].load()
            if now != seen:
                seen = now
                since = Int(monotonic())
            elif Int(monotonic()) - since > ROUND_BOUND_NS:
                abort(String("run parks: lost wake in round ", now))
        var unit: NoneType = None
        return Optional(Result[NoneType, EffectFailure[Error]](Ok(unit)))


# What a waker thread does after its delay.
comptime COMPLETE = 0
comptime NOTIFY = 1
comptime CANCEL = 2


struct Waker(ReaderAction):
    """Runs on an OS thread: wait, write plain data, then wake the root one way."""
    var kind: Int
    var delay: Int
    var data: ArcPointer[Int]
    var stamp: Int
    var completion: Optional[Completion[Int, Int]]
    var signal: Optional[Signal]
    var flag: Optional[ArcPointer[Atomic[UInt8]]]
    var token: Optional[CancellationToken]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def __init__(out self, kind: Int, delay: Int, data: ArcPointer[Int], stamp: Int):
        self.kind = kind
        self.delay = delay
        self.data = data.copy()
        self.stamp = stamp
        self.completion = None
        self.signal = None
        self.flag = None
        self.token = None

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        spin(self.delay)
        # Plain data, published by the wake's lock.
        self.data[] = self.stamp
        if self.kind == COMPLETE:
            _ = self.completion.value().complete(Optional(Result[Int, EffectFailure[Int]](Ok(self.stamp))))
        elif self.kind == NOTIFY:
            self.flag.value()[].store(1)
            self.signal.value().notify()
        else:
            self.token.value().cancel()
        var unit: NoneType = None
        return Optional(Result[NoneType, EffectFailure[Error]](Ok(unit)))


struct Started(Movable):
    var thread: Optional[Thread[Waker]]

    def __init__(out self):
        self.thread = None

    def join(mut self):
        check(Bool(self.thread), "the waker thread started")
        var outcome = self.thread.take().join()
        check(Bool(outcome) and outcome.value().is_ok(), "the waker thread finished")


def start(var waker: Waker) -> Thread[Waker]:
    try:
        return unsafe_start(waker^)
    except:
        abort("run parks: unsafe_start failed")


struct Register(OnceUnary):
    """Hand the completion to a new OS thread, then vary the root's side of the race."""
    var started: ArcPointer[Started]
    var data: ArcPointer[Int]
    var stamp: Int
    var delay: Int
    var root_delay: Int
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def __init__(out self, started: ArcPointer[Started], data: ArcPointer[Int], stamp: Int, delay: Int, root_delay: Int):
        self.started = started.copy()
        self.data = data.copy()
        self.stamp = stamp
        self.delay = delay
        self.root_delay = root_delay

    def call_once(deinit self, var done: Completion[Int, Int]) -> NoneType:
        var waker = Waker(COMPLETE, self.delay, self.data, self.stamp)
        waker.completion = Optional(done^)
        self.started[].thread = Optional(start(waker^))
        spin(self.root_delay)
        return None


@fieldwise_init
struct Observe(OnceUnary):
    var data: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        check(self.data[] == value, "data written before the completion is visible")
        return value


@fieldwise_init
struct AwaitFlag(Machine):
    """A custom leaf: read the revision, then the flag, then wait for a change."""
    var signal: Signal
    var flag: ArcPointer[Atomic[UInt8]]
    var data: ArcPointer[Int]
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        var revision = self.signal.revision()
        if self.flag[].load() != 0:
            return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(self.data[]))))
        return .pending(Wait.changed(self.signal, revision))


def foreign_wakes():
    var random = Random(0x9A4C)
    var round = ArcPointer(Atomic(0))
    var done = ArcPointer(Atomic(UInt8(0)))
    var watchdog = start_watchdog(round, done)
    for stamp in range(1, ROUNDS + 1):
        _ = round[].fetch_add(1)
        var data = ArcPointer(0)
        # From no delay to about 100 microseconds on each side.
        var delay = random.below(11) * 10_000
        var root_delay = random.below(11) * 10_000
        var kind = stamp % 3
        if kind == COMPLETE:
            var started = ArcPointer(Started())
            var program = IO[Int, Int].`async_`(Register(started, data, stamp, delay, root_delay)).map(Observe(data.copy()))
            var outcome = run(program^)
            check(Bool(outcome) and outcome.take()._take_ok() == stamp, "a foreign completion resumes the root")
            started[].join()
        elif kind == NOTIFY:
            var signal = Signal()
            var flag = ArcPointer(Atomic(UInt8(0)))
            var waker = Waker(NOTIFY, delay, data, stamp)
            waker.signal = Optional(signal.copy())
            waker.flag = Optional(flag.copy())
            var thread = start(waker^)
            spin(root_delay)
            var outcome = run(IO[Int, Int].lift(AwaitFlag(signal^, flag.copy(), data.copy())))
            check(Bool(outcome) and outcome.take()._take_ok() == stamp, "a foreign notify resumes the root, with its data")
            check(Bool(thread^.join()), "the notifier finished")
        else:
            var token = CancellationToken()
            var waker = Waker(CANCEL, delay, data, stamp)
            waker.token = Optional(token.copy())
            var thread = start(waker^)
            spin(root_delay)
            var outcome = run(IO[Int, Int].never(), token)
            check(not outcome, "a foreign cancellation ends a root waiting forever")
            check(data[] == stamp, "data written before the cancellation is visible")
            check(Bool(thread^.join()), "the canceler finished")
    done[].store(1)
    check(Bool(watchdog^.join()), "the watchdog finished")
    print("foreign wakes: completions, signals and cancellations before or during a park are never lost")


def start_watchdog(round: ArcPointer[Atomic[Int]], done: ArcPointer[Atomic[UInt8]]) -> Thread[Watchdog]:
    try:
        return unsafe_start(Watchdog(round, done))
    except:
        abort("run parks: unsafe_start failed")


def main() raises:
    idle_sleep()
    timers()
    foreign_wakes()
