"""OS threads notify a Signal and cancel a token while the main thread polls a Driver.

A custom leaf reads the signal's revision, inspects shared state only after a
changed revision, and otherwise waits with Wait.changed. Foreign threads write
plain data before notifying or canceling; the polling thread must see it.
"""
from std.atomic import Atomic
from std.ffi import external_call
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, unsafe_start
from fp.effects import Fiber as Thread
from fp.effects import IO as SyncIO
from fp.effects.protocols import ReaderAction
from fp.effects.async_runtime import IO, Fiber, Clock, Driver
from fp.effects.async_runtime.protocols import Machine, Step, Wait, Signal


comptime WORDS = 16
comptime ROUND_BOUND_NS = 2_000_000_000
comptime SIGNAL_ROUNDS = 1000
comptime CANCEL_ROUNDS = 150


def check(condition: Bool, message: String):
    if not condition:
        abort(String("foreign signal: ", message))


def spin(nanoseconds: Int):
    var end = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < end:
        pass


struct Random(Movable):
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def below(mut self, bound: Int) -> Int:
        self.state = self.state * 6364136223846793005 + 1442695040888963407
        return Int((self.state >> 33) % UInt64(bound))


def fresh_data() -> ArcPointer[List[Int]]:
    var words = List[Int]()
    for _ in range(WORDS):
        words.append(-1)
    return ArcPointer(words^)


def published(data: ArcPointer[List[Int]], stamp: Int) -> Bool:
    for i in range(WORDS):
        if data[][i] != stamp * 1000 + i:
            return False
    return True


def publish(data: ArcPointer[List[Int]], stamp: Int):
    # Plain writes, published only by the following notify or cancel.
    for i in range(WORDS):
        data[][i] = stamp * 1000 + i


struct Notifier(ReaderAction):
    """Runs on a foreign thread: wait, publish plain data, then notify."""
    var signal: Signal
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var delay: Int
    var repeats: Int
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Error]

    def __init__(out self, signal: Signal, data: ArcPointer[List[Int]], stamp: Int, delay: Int, repeats: Int):
        self.signal = signal.copy()
        self.data = data.copy()
        self.stamp = stamp
        self.delay = delay
        self.repeats = repeats

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        spin(self.delay)
        publish(self.data, self.stamp)
        for _ in range(self.repeats):
            self.signal.notify()
        return Optional(Result[Int, EffectFailure[Error]](Ok(self.stamp)))


struct Canceller(ReaderAction):
    """Runs on a foreign thread: wait, publish plain data, then cancel."""
    var token: CancellationToken
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var delay: Int
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Error]

    def __init__(out self, token: CancellationToken, data: ArcPointer[List[Int]], stamp: Int, delay: Int):
        self.token = token.copy()
        self.data = data.copy()
        self.stamp = stamp
        self.delay = delay

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        spin(self.delay)
        publish(self.data, self.stamp)
        self.token.cancel()
        return Optional(Result[Int, EffectFailure[Error]](Ok(self.stamp)))


# A live Driver is linear, so starting a thread beside one must not raise.
def start_notifier(signal: Signal, data: ArcPointer[List[Int]], stamp: Int, delay: Int, repeats: Int) -> Thread[Notifier]:
    try:
        return unsafe_start(Notifier(signal, data, stamp, delay, repeats))
    except:
        abort("foreign signal: unsafe_start failed")


def start_canceller(token: CancellationToken, data: ArcPointer[List[Int]], stamp: Int, delay: Int) -> Thread[Canceller]:
    try:
        return unsafe_start(Canceller(token, data, stamp, delay))
    except:
        abort("foreign signal: unsafe_start failed")


def join[P: ReaderAction](var thread: Thread[P]) -> Int where P.Value == Int:
    var outcome = thread^.join()
    check(Bool(outcome), "foreign thread finished")
    var result = outcome.take()
    check(result.is_ok(), "foreign thread succeeded")
    return rebind_var[Int](result^._take_ok())


struct Watch(Machine):
    """A custom leaf: shared state is read only after a changed revision."""
    var signal: Signal
    var baseline: UInt64
    var data: ArcPointer[List[Int]]
    var stamp: Int
    # Spin between reading the revision and parking, widening the window in
    # which a foreign notify must still be observed.
    var gap: Int
    var polls: ArcPointer[Int]
    comptime Value = Int
    comptime Error = Int

    def __init__(out self, signal: Signal, data: ArcPointer[List[Int]], stamp: Int, gap: Int, polls: ArcPointer[Int]):
        self.signal = signal.copy()
        # Taken before the notifier starts, so an early notify is a change.
        self.baseline = signal.revision()
        self.data = data.copy()
        self.stamp = stamp
        self.gap = gap
        self.polls = polls.copy()

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.polls[] += 1
        if context.canceled():
            return .ready(None)
        var revision = self.signal.revision()
        if revision != self.baseline:
            check(published(self.data, self.stamp), "data written before notify is visible after the changed revision")
            return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(self.stamp))))
        spin(self.gap)
        return .pending(Wait.changed(self.signal, revision))


struct Parked(Machine):
    """A custom leaf waiting only for cancellation."""
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var observed: ArcPointer[Int]
    comptime Value = NoneType
    comptime Error = Int

    def __init__(out self, data: ArcPointer[List[Int]], stamp: Int, observed: ArcPointer[Int]):
        self.data = data.copy()
        self.stamp = stamp
        self.observed = observed.copy()

    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        if context.canceled():
            check(published(self.data, self.stamp), "data written before cancel is visible to the canceled leaf")
            self.observed[] += 1
            return .ready(None)
        return .pending(Wait.never())


struct Audit(Machine):
    """A finalizer of a canceled fiber: data written before cancel is visible."""
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var observed: ArcPointer[Int]
    comptime Value = NoneType
    comptime Error = Int

    def __init__(out self, data: ArcPointer[List[Int]], stamp: Int, observed: ArcPointer[Int]):
        self.data = data.copy()
        self.stamp = stamp
        self.observed = observed.copy()

    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        check(published(self.data, self.stamp), "data written before cancel is visible to the finalizer")
        self.observed[] += 1
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))


@fieldwise_init
struct JoinChild(OnceUnary):
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var child: Fiber[NoneType, Int]) -> IO[NoneType, Int]:
        return child^.join_with_unit()


def drive[P: Machine](mut driver: Driver[P], mut random: Random, quiet_spin: Int) -> Int:
    """Poll until completion within the round bound; returns the number of idle polls."""
    var deadline = Int(monotonic()) + ROUND_BOUND_NS
    var idle = 0
    while True:
        var progress = driver.poll()
        if progress.completed:
            return idle
        if not progress.runnable:
            idle += 1
            spin(random.below(quiet_spin + 1))
        check(Int(monotonic()) < deadline, "lost wake: round exceeded its bound")


def signal_wakes_leaf() raises:
    """Many rounds: one or two leaves wait on a signal a foreign thread notifies."""
    var random = Random(0x51611A1)
    var idle_rounds = 0
    var early = 0
    for stamp in range(1, SIGNAL_ROUNDS + 1):
        var signal = Signal()
        var data = fresh_data()
        var polls = ArcPointer(0)
        var gap = random.below(4) * 10_000
        var delay = random.below(5) * 10_000
        var repeats = 1 + random.below(3)
        var pair = stamp % 3 == 0
        # Start the thread before or after the first poll.
        var before = stamp % 2 == 0
        var thread: Optional[Thread[Notifier]] = None
        # Leaves take their baseline revisions here, before any notifier runs.
        var first = Watch(signal, data, stamp, gap, polls)
        var second = Watch(signal, data, stamp, gap, polls)
        if before:
            thread = Optional(start_notifier(signal, data, stamp, delay, repeats))
        if pair:
            var driver = Driver(IO[Int, Int].lift(first^).both(IO[Int, Int].lift(second^)))
            if not before:
                _ = driver.poll()
                thread = Optional(start_notifier(signal, data, stamp, delay, repeats))
            if drive(driver, random, 40_000):
                idle_rounds += 1
            var outcome = driver^.finish()
            check(Bool(outcome), "pair completed")
            var both = outcome.take()._take_ok()
            check(both[0] == stamp and both[1] == stamp, "both leaves woke on one signal")
        else:
            _ = second^
            var driver = Driver(IO[Int, Int].lift(first^))
            if not before:
                _ = driver.poll()
                thread = Optional(start_notifier(signal, data, stamp, delay, repeats))
            if drive(driver, random, 40_000):
                idle_rounds += 1
            var outcome = driver^.finish()
            check(Bool(outcome) and outcome.take()._take_ok() == stamp, "leaf completed")
        if polls[] == (2 if pair else 1):
            early += 1
        check(join(thread.take()) == stamp, "notifier joined")
    check(idle_rounds > 0, "some rounds waited for the foreign thread")
    check(early < SIGNAL_ROUNDS, "some rounds parked before the notify")


def cancel_wakes_waiter() raises:
    """A foreign cancel wakes a parked leaf, a root fiber and a started child fiber."""
    var random = Random(0xCA9CE1)
    for stamp in range(1, CANCEL_ROUNDS + 1):
        var data = fresh_data()
        var observed = ArcPointer(0)
        var token = CancellationToken()
        var delay = random.below(5) * 10_000
        var kind = stamp % 3
        var thread: Thread[Canceller]
        if kind == 0:
            var driver = Driver(IO[NoneType, Int].lift(Parked(data, stamp, observed)), token, Clock())
            _ = driver.poll()
            thread = start_canceller(token, data, stamp, delay)
            _ = drive(driver, random, 40_000)
            var outcome = driver^.finish()
            check(not outcome, "parked leaf canceled")
        elif kind == 1:
            var program = IO[NoneType, Int].never().guarantee(IO[NoneType, Int].lift(Audit(data, stamp, observed)))
            var driver = Driver(program^, token, Clock())
            _ = driver.poll()
            thread = start_canceller(token, data, stamp, delay)
            _ = drive(driver, random, 40_000)
            var outcome = driver^.finish()
            check(not outcome, "waiting root canceled")
        else:
            var child = IO[NoneType, Int].never().guarantee(IO[NoneType, Int].lift(Audit(data, stamp, observed)))
            var program = child^.start().flat_map(JoinChild())
            var driver = Driver(program^, token, Clock())
            _ = driver.poll()
            thread = start_canceller(token, data, stamp, delay)
            _ = drive(driver, random, 40_000)
            var outcome = driver^.finish()
            check(not outcome, "root joining a waiting child canceled")
        check(observed[] == 1, "the waiter observed cancellation once")
        check(join(thread^) == stamp, "canceller joined")


def main() raises:
    signal_wakes_leaf()
    cancel_wakes_waiter()
    print("foreign signal: Wait.changed leaves woken across threads, cancellation observed by leaves, roots and child fibers, data published before each call")
