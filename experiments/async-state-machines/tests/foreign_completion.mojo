"""OS threads complete IO.async registrations while the main thread polls a Driver.

Each round starts one producer thread with unsafe_start from the registration
callback. The producer writes plain data, then completes with an owned payload.
The polling thread observes the data in a continuation. Late, duplicate and
withdrawn completions are rejected and their payloads are destroyed on the
producer thread before complete returns.
"""
from std.atomic import Atomic
from std.ffi import external_call
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, Fiber, unsafe_start
from fp.effects import IO as SyncIO
from fp.effects.protocols import ReaderAction
from fp.effects.async_runtime import IO, Completion, Clock, Driver, Duration, Progress
from fp.effects.async_runtime.protocols import Machine, Step, Wait


comptime WORDS = 16
comptime ROUND_BOUND_NS = 2_000_000_000
comptime LOST_WAKE_ROUNDS = 1000
comptime RACE_BASE = 100_000
comptime RACE_ROUNDS = 400


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def check(condition: Bool, message: String):
    if not condition:
        abort(String("foreign completion: ", message))


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


struct Ledger(Movable):
    """Payload accounting shared by both threads; every field is atomic."""
    var created: Atomic[Int]
    var destroyed: Atomic[Int]

    def __init__(out self):
        self.created = Atomic(Int(0))
        self.destroyed = Atomic(Int(0))


struct Payload(Movable):
    """An owned completion value with heap contents and one observed destruction."""
    var text: String
    var stamp: Int
    var ledger: ArcPointer[Ledger]
    # The destroying thread, or zero while alive.
    var destroyed_on: ArcPointer[Atomic[UInt64]]

    def __init__(out self, stamp: Int, ledger: ArcPointer[Ledger], destroyed_on: ArcPointer[Atomic[UInt64]]):
        self.text = String("payload-", stamp, "-", "x" * 48)
        self.stamp = stamp
        self.ledger = ledger.copy()
        self.destroyed_on = destroyed_on.copy()
        _ = self.ledger[].created.fetch_add(1)

    def __deinit__(deinit self):
        var expected = UInt64(0)
        if not self.destroyed_on[].compare_exchange(expected, thread_id()):
            abort("foreign completion: payload destroyed twice")
        _ = self.ledger[].destroyed.fetch_add(1)


def offer(stamp: Int, ledger: ArcPointer[Ledger], destroyed_on: ArcPointer[Atomic[UInt64]]) -> Outcome[Payload, Int]:
    return Optional(Result[Payload, EffectFailure[Int]](Ok(Payload(stamp, ledger, destroyed_on))))


def expected_text(stamp: Int) -> String:
    return String("payload-", stamp, "-", "x" * 48)


# Producer outcome codes, returned through the thread's Fiber.
comptime ACCEPTED = 1
comptime REJECTED = 2
comptime GATE_TIMEOUT = 3
comptime BAD_DUPLICATE = 4


struct Producer(ReaderAction):
    """Runs on a foreign thread: wait, publish plain data, then complete."""
    var completion: Completion[Payload, Int]
    var ledger: ArcPointer[Ledger]
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var delay: Int
    var duplicate: Bool
    # When present, wait until the polling thread opens it before completing.
    var gate: Optional[ArcPointer[Atomic[UInt8]]]
    var destroyed_on: ArcPointer[Atomic[UInt64]]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Error]

    def __init__(out self, var completion: Completion[Payload, Int], ledger: ArcPointer[Ledger], data: ArcPointer[List[Int]], stamp: Int, delay: Int, duplicate: Bool, gate: Optional[ArcPointer[Atomic[UInt8]]], destroyed_on: ArcPointer[Atomic[UInt64]]):
        self.completion = completion^
        self.ledger = ledger.copy()
        self.data = data.copy()
        self.stamp = stamp
        self.delay = delay
        self.duplicate = duplicate
        self.gate = gate.copy()
        self.destroyed_on = destroyed_on.copy()

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        if self.gate:
            var deadline = Int(monotonic()) + ROUND_BOUND_NS
            while self.gate.value()[].load() == 0:
                if Int(monotonic()) > deadline:
                    return Optional(Result[Int, EffectFailure[Error]](Ok(GATE_TIMEOUT)))
        spin(self.delay)
        # Plain writes, published only by the completion's lock.
        for i in range(WORDS):
            self.data[][i] = self.stamp * 1000 + i
        var accepted = self.completion.complete(offer(self.stamp, self.ledger, self.destroyed_on))
        var code = ACCEPTED if accepted else REJECTED
        if self.duplicate:
            var second_on = ArcPointer(Atomic(UInt64(0)))
            var again = self.completion.complete(offer(-self.stamp, self.ledger, second_on))
            # Rejected here and destroyed on this thread before complete returned.
            if again or second_on[].load() != thread_id():
                code = BAD_DUPLICATE
        return Optional(Result[Int, EffectFailure[Error]](Ok(code)))


struct Round(Movable):
    """The polling thread's view of one round, shared with its callables."""
    var thread: Optional[Fiber[Producer]]
    var withdrawn: Int
    var held: Optional[Int]

    def __init__(out self):
        self.thread = None
        self.withdrawn = 0
        self.held = None

    def join(mut self) -> Int:
        check(Bool(self.thread), "producer thread was started")
        var outcome = self.thread.take().join()
        check(Bool(outcome), "producer finished")
        var result = outcome.take()
        check(result.is_ok(), "producer succeeded")
        return result^._take_ok()


struct Register(OnceUnary):
    """Runs on the polling thread and hands the completion to a new OS thread."""
    var round: ArcPointer[Round]
    var ledger: ArcPointer[Ledger]
    var data: ArcPointer[List[Int]]
    var stamp: Int
    var delay: Int
    var duplicate: Bool
    var gate: Optional[ArcPointer[Atomic[UInt8]]]
    var destroyed_on: ArcPointer[Atomic[UInt64]]
    comptime Arg = Completion[Payload, Int]
    comptime Out = NoneType

    def __init__(out self, round: ArcPointer[Round], ledger: ArcPointer[Ledger], data: ArcPointer[List[Int]], stamp: Int, delay: Int, duplicate: Bool, gate: Optional[ArcPointer[Atomic[UInt8]]], destroyed_on: ArcPointer[Atomic[UInt64]]):
        self.round = round.copy()
        self.ledger = ledger.copy()
        self.data = data.copy()
        self.stamp = stamp
        self.delay = delay
        self.duplicate = duplicate
        self.gate = gate.copy()
        self.destroyed_on = destroyed_on.copy()

    def call_once(deinit self, var done: Completion[Payload, Int]) -> NoneType:
        try:
            self.round[].thread = Optional(unsafe_start(Producer(done^, self.ledger, self.data, self.stamp, self.delay, self.duplicate, self.gate, self.destroyed_on)))
        except:
            abort("foreign completion: unsafe_start failed")
        return None


@fieldwise_init
struct Observe(OnceUnary):
    """The continuation on the polling thread: payload and plain data must be complete."""
    var data: ArcPointer[List[Int]]
    var stamp: Int
    comptime Arg = Payload
    comptime Out = Int

    def call_once(deinit self, var payload: Payload) -> Int:
        check(payload.stamp == self.stamp and payload.text == expected_text(self.stamp), "payload arrives intact")
        for i in range(WORDS):
            check(self.data[][i] == self.stamp * 1000 + i, "data written before complete is visible")
        check(payload.destroyed_on[].load() == 0, "payload alive in its continuation")
        return payload.stamp


@fieldwise_init
struct Withdraw(Machine):
    var round: ArcPointer[Round]
    comptime Value = NoneType
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        self.round[].withdrawn += 1
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))


@fieldwise_init
struct Hold(OnceUnary):
    """Record the selected value, then keep the root alive until canceled."""
    var round: ArcPointer[Round]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.round[].held = Optional(value)
        return IO[Int, Int].never()


def source(round: ArcPointer[Round], ledger: ArcPointer[Ledger], data: ArcPointer[List[Int]], stamp: Int, delay: Int, duplicate: Bool, gate: Optional[ArcPointer[Atomic[UInt8]]], destroyed_on: ArcPointer[Atomic[UInt64]]) -> IO[Int, Int]:
    var register = Register(round, ledger, data, stamp, delay, duplicate, gate, destroyed_on)
    return IO[Payload, Int].`async`(register^, IO[NoneType, Int].lift(Withdraw(round.copy()))).map(Observe(data.copy(), stamp))


def fresh_data() -> ArcPointer[List[Int]]:
    var words = List[Int]()
    for _ in range(WORDS):
        words.append(-1)
    return ArcPointer(words^)


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
            # Vary the polling thread's side of the race.
            spin(random.below(quiet_spin + 1))
        check(Int(monotonic()) < deadline, "lost wake: round exceeded its bound")


def advance(clock: Clock, progress: Progress):
    # Driver is linear: advancing must not raise while one is live.
    try:
        clock.advance_to(progress.deadline.value())
    except:
        abort("foreign completion: manual clock advance")


def drain[P: Machine](mut driver: Driver[P]):
    var deadline = Int(monotonic()) + ROUND_BOUND_NS
    while True:
        if driver.poll().completed:
            return
        check(Int(monotonic()) < deadline, "root drains within its bound")


def no_lost_wake(ledger: ArcPointer[Ledger]):
    """Many rounds with varied delays on both sides; every program completes."""
    var random = Random(0x5EED)
    var duplicates = 0
    var idle_rounds = 0
    for stamp in range(1, LOST_WAKE_ROUNDS + 1):
        var round = ArcPointer(Round())
        var data = fresh_data()
        var destroyed_on = ArcPointer(Atomic(UInt64(0)))
        # Delays from none to about 40 microseconds on each side.
        var producer_delay = random.below(5) * 10_000
        var duplicate = stamp % 4 == 0
        var driver = Driver(source(round, ledger, data, stamp, producer_delay, duplicate, None, destroyed_on))
        var idle = drive(driver, random, 40_000)
        if idle:
            idle_rounds += 1
        var outcome = driver^.finish()
        check(Bool(outcome), "round completed")
        var result = outcome.take()
        check(result.is_ok() and result^._take_ok() == stamp, "round produced its own payload")
        check(destroyed_on[].load() == thread_id(), "accepted payload destroyed by the polling thread")
        var code = round[].join()
        check(code == ACCEPTED, "first completion accepted; a duplicate rejected on its thread")
        check(round[].withdrawn == 1, "withdrawal runs once after every entered registration")
        if duplicate:
            duplicates += 1
    check(duplicates == LOST_WAKE_ROUNDS // 4, "duplicate rounds")
    # Rounds where the polling thread had to wait at least once exercise the
    # wake path; with these delays most rounds do.
    check(idle_rounds > 0, "some rounds waited for the foreign thread")


def withdrawn_then_late(ledger: ArcPointer[Ledger]) raises:
    """Completion after the timeout withdrew the registration is rejected and wakes nothing."""
    for stamp in range(1001, 1021):
        var clock = Clock.manual()
        var round = ArcPointer(Round())
        var data = fresh_data()
        var gate = ArcPointer(Atomic(UInt8(0)))
        var destroyed_on = ArcPointer(Atomic(UInt64(0)))
        var program = source(round, ledger, data, stamp, 0, False, Optional(gate.copy()), destroyed_on).timeout_to(Duration.milliseconds(5), IO[Int, Int].pure(-1)).flat_map(Hold(round.copy()))
        var token = CancellationToken()
        var driver = Driver(program^, token, clock)
        var first = driver.poll()
        check(not first.completed and not first.runnable and Bool(first.deadline), "registration waits on the timeout")
        advance(clock, first)
        var held = driver.poll()
        check(not held.completed and not held.runnable, "root holds after the timeout")
        check(round[].withdrawn == 1 and round[].held.value() == -1, "timeout withdrew the registration")
        gate[].store(1)
        var code = round[].join()
        check(code == REJECTED, "completion after withdrawal is rejected")
        check(destroyed_on[].load() != 0 and destroyed_on[].load() != thread_id(), "rejected payload destroyed on the producer thread")
        for i in range(WORDS):
            check(data[][i] == stamp * 1000 + i, "producer data is visible after joining")
        var after = driver.poll()
        check(after.polls == 0 and not after.runnable and not after.completed, "rejected completion wakes nothing")
        driver.request_cancel()
        drain(driver)
        var outcome = driver^.finish()
        check(not outcome, "held root canceled")


def finished_then_late(ledger: ArcPointer[Ledger]) raises:
    """Completion after the root finished, by timeout or cancellation, is rejected."""
    for stamp in range(2001, 2021):
        var round = ArcPointer(Round())
        var data = fresh_data()
        var gate = ArcPointer(Atomic(UInt8(0)))
        var destroyed_on = ArcPointer(Atomic(UInt64(0)))
        var by_cancel = stamp % 2 == 0
        var token = CancellationToken()
        var clock = Clock.manual()
        var program = source(round, ledger, data, stamp, 0, True, Optional(gate.copy()), destroyed_on).timeout_to(Duration.milliseconds(5), IO[Int, Int].pure(-1))
        var driver = Driver(program^, token, clock)
        var first = driver.poll()
        check(not first.completed and not first.runnable, "registration waits")
        if by_cancel:
            token.cancel()
        else:
            advance(clock, first)
        drain(driver)
        var outcome = driver^.finish()
        if by_cancel:
            check(not outcome, "root canceled")
        else:
            check(Bool(outcome) and outcome.take()._take_ok() == -1, "root timed out")
        check(round[].withdrawn == 1, "registration withdrawn once")
        gate[].store(1)
        # BAD_DUPLICATE would report a second offer accepted or destroyed elsewhere.
        var code = round[].join()
        check(code == REJECTED, "completion after the root finished is rejected")
        check(destroyed_on[].load() != 0 and destroyed_on[].load() != thread_id(), "rejected payload destroyed on the producer thread")


def racing_withdrawal(ledger: ArcPointer[Ledger]) raises:
    """A producer racing a real-time timeout: exactly one consistent decision."""
    var random = Random(0xC0FFEE)
    var accepted_values = 0
    var rejected = 0
    var accepted_dropped = 0
    for stamp in range(RACE_BASE + 1, RACE_BASE + RACE_ROUNDS + 1):
        var round = ArcPointer(Round())
        var data = fresh_data()
        var destroyed_on = ArcPointer(Atomic(UInt64(0)))
        var producer_delay = random.below(400_000)
        var program = source(round, ledger, data, stamp, producer_delay, False, None, destroyed_on).timeout_to(Duration.nanoseconds(200_000), IO[Int, Int].pure(-1))
        var driver = Driver(program^)
        _ = drive(driver, random, 20_000)
        var outcome = driver^.finish()
        check(Bool(outcome), "racing round completes")
        var value = outcome.take()._take_ok()
        var code = round[].join()
        check(destroyed_on[].load() != 0, "payload destroyed exactly once")
        if code == REJECTED:
            check(value == -1 and round[].withdrawn == 1, "rejected completion selects the timeout")
            check(destroyed_on[].load() != thread_id(), "rejected payload destroyed on the producer thread")
            rejected += 1
        else:
            check(code == ACCEPTED, "producer accepted or rejected")
            check(destroyed_on[].load() == thread_id(), "accepted payload destroyed on the polling thread")
            if value == stamp:
                accepted_values += 1
            else:
                # Accepted after the timeout began withdrawing: the outcome is
                # taken and dropped by the canceled registration.
                check(value == -1, "accepted payload or timeout value")
                accepted_dropped += 1
    check(accepted_values + rejected + accepted_dropped == RACE_ROUNDS, "every race decided")


def main() raises:
    var ledger = ArcPointer(Ledger())
    no_lost_wake(ledger)
    withdrawn_then_late(ledger)
    finished_then_late(ledger)
    racing_withdrawal(ledger)
    check(ledger[].created.load() == ledger[].destroyed.load(), "every payload destroyed exactly once")
    print("foreign completion: no lost wake, published data, owned payloads, duplicate, withdrawn, finished and racing completions rejected on their thread")
