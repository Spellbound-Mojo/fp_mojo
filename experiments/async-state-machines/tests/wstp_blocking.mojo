"""The blocking hand-off on the work-stealing pool.

Each scenario runs a root on a pool made for it, with the calling thread as
worker 0, through the same steps as the private entry point (`_run_pooled`),
so that a scenario can set the pool's cap and idle timeout and read its thread
cache. Checks:

- a blocking call on worker 0 runs on the calling thread, which left the
  worker; a replacement runs the worker's queue, so another fiber makes
  progress during the 100 ms call;
- an interruptible call's `Interruption.sleep` on a handed-off thread is woken
  by cancellation through the token's bridge, and the cancellation completes
  after the function returns;
- with a cap of 2, two calls hand off and the others queue on the root's
  pool, all running at once;
- a thread that ran a call is reused while idle and retires after the idle
  timeout;
- results and errors return through the hand-off;
- a configured `BlockingPool(max_workers=1)` is honored: its calls do not
  hand off and still run one at a time.
"""
from std.atomic import Atomic, Ordering
from std.ffi import external_call
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import stderr
from std.time import perf_counter_ns, sleep
from fp.callables import OnceThunk, OnceUnary, BorrowCallable
from fp.effects import CancellationToken, Outcome, Interruption
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, BlockingPool, Duration
from fp.effects._async.kernel import Machine
from fp.effects._async.pool import _Pool, _pool_at, _submit_root

comptime WORDS = 16
# Probe words.
comptime POOL = 0
comptime TICKS = 1
comptime STOP = 2
comptime ON_CALLER = 3
comptime OWN = 4
comptime TICKS_BEFORE = 5
comptime TICKS_AFTER = 6
comptime NAPPED = 7
comptime RUNNING = 8
comptime RUNNING_HIGH = 9
comptime HANDED_HIGH = 11
comptime LIVE = 13
comptime STARTED = 14


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_blocking: ", message))


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def ms(count: Int) -> Duration:
    var duration = Duration()
    duration._nanoseconds = count * 1_000_000
    return duration^


struct Words(Movable):
    """Counters shared by a scenario's threads, in their own allocation."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.words = unsafe_alloc[Atomic[Int]](WORDS)
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_deinit_pointee()
        self.words.unsafe_free()

    def get(self, word: Int) -> Int:
        return self.words[unsafe_offset=word].load[ordering=Ordering.SEQUENTIAL]()

    def set(self, word: Int, value: Int):
        self.words[unsafe_offset=word].store[ordering=Ordering.SEQUENTIAL](value)

    def add(self, word: Int, value: Int) -> Int:
        return self.words[unsafe_offset=word].fetch_add[ordering=Ordering.SEQUENTIAL](value) + value

    def enter(self, word: Int):
        """Count one more in progress at `word` and raise its high-water mark at `word + 1`."""
        self.raise_to(word + 1, self.add(word, 1))

    def raise_to(self, word: Int, value: Int):
        """Raise the high-water mark at `word` to `value`."""
        var high = self.get(word)
        while value > high:
            if self.words[unsafe_offset=word].compare_exchange(high, value):
                break

    def handed_off(self) -> Int:
        """Calls handed off now on this scenario's pool (the cap's count); 0 before its first hand-off."""
        return _pool_at(self.get(POOL))[].blockers()[].blocked.in_flight()


comptime Probe = ArcPointer[Words]


def run_on[P: Machine](var program: P, probe: Probe, workers: Int, cap: Int, idle: Duration, config: IORuntimeConfig) -> Outcome[P.Value, P.Error]:
    """Run `program` as `_run_pooled` does, on a pool with the given cap and idle timeout."""
    var pool: ArcPointer[_Pool]
    try:
        pool = ArcPointer(_Pool(workers, 1, max_blocking_threads=cap, blocking_idle_timeout=idle))
    except error:
        abort(String("wstp_blocking: could not create a pool: ", error))
    var target = Int(Pointer(to=pool[]))
    probe[].set(POOL, target)
    pool[].enter(0)
    var handle = _submit_root(pool, program^, CancellationToken(), config)
    _ = pool[].run_worker(target, 0, False, handle.done_address())
    var outcome = handle^.take()
    pool[].shutdown()
    return outcome^


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("wstp_blocking: expected a success")
    return outcome.take()._take_ok()


# ===--- A fiber that counts its own steps until told to stop ---=== #


@fieldwise_init
struct Tick(OnceUnary):
    var probe: Probe
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.probe[].get(STOP):
            return IO[NoneType, Int].pure(None)
        _ = self.probe[].add(TICKS, 1)
        return IO[NoneType, Int].cede().flat_map(Self(self.probe^))


def counter(probe: Probe) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Tick(probe.copy()))


# ===--- Scenario 1: hand-off on worker 0 and progress during the call ---=== #


@fieldwise_init
struct Slow(OnceThunk):
    """A 100 ms blocking call that records where it ran and the counter's progress meanwhile."""
    var probe: Probe
    var caller: UInt64
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.probe[].set(ON_CALLER, 1 if thread_id() == self.caller else 2)
        self.probe[].set(OWN, self.probe[].handed_off())
        self.probe[].set(TICKS_BEFORE, self.probe[].get(TICKS))
        sleep(0.1)
        self.probe[].set(TICKS_AFTER, self.probe[].get(TICKS))
        return 42


@fieldwise_init
struct BlockThenStop(OnceUnary):
    var probe: Probe
    var caller: UInt64
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Int, Int]:
        return IO[Int, Int].blocking(Slow(self.probe.copy(), self.caller)).flat_map(StopAndJoin(self.probe^, fiber^))


@fieldwise_init
struct StopAndJoin(OnceUnary):
    var probe: Probe
    var fiber: Fiber[NoneType, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.probe[].set(STOP, 1)
        return self.fiber^.join().flat_map(Keep(value))


@fieldwise_init
struct Keep(OnceUnary):
    var value: Int
    comptime Arg = Outcome[NoneType, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[NoneType, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "the counting fiber succeeds")
        return IO[Int, Int].pure(self.value)


def hand_off_progress():
    var probe = Probe(Words())
    var program = counter(probe).start().flat_map(BlockThenStop(probe.copy(), thread_id()))
    check(value_of(run_on(program^, probe, 1, 64, ms(60_000), IORuntimeConfig())) == 42, "the blocking call's result returns")
    check(probe[].get(ON_CALLER) == 1, "a call made on worker 0 runs on the calling thread, which handed the worker off")
    check(probe[].get(OWN) == 1, "the call counts against the cap while it runs")
    var progress = probe[].get(TICKS_AFTER) - probe[].get(TICKS_BEFORE)
    print("wstp_blocking: counter steps during the 100 ms call:", progress, file=stderr)
    check(progress >= 10, String("another fiber makes progress during the call: ", progress))


# ===--- Scenario 2: cancellation wakes an interruptible wait through the bridge ---=== #


@fieldwise_init
struct LongNap(BorrowCallable):
    var probe: Probe
    var caller: UInt64
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        self.probe[].set(ON_CALLER, 1 if thread_id() == self.caller else 2)
        self.probe[].set(NAPPED, 1 if handle.sleep(ms(10_000)) else 2)
        return 0


@fieldwise_init
struct NapThenCancel(OnceUnary):
    var start: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return IO[NoneType, Int].sleep(ms(20)).flat_map(Cancel(fiber^, self.start))


@fieldwise_init
struct Cancel(OnceUnary):
    var fiber: Fiber[Int, Int]
    var start: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber.cancel().flat_map(Elapsed(self.start))


@fieldwise_init
struct Elapsed(OnceUnary):
    var start: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].pure(Int(perf_counter_ns() - self.start) // 1_000_000)


def interruptible_cancel():
    var probe = Probe(Words())
    var program = IO[Int, Int].interruptible(LongNap(probe.copy(), thread_id())).start().flat_map(NapThenCancel(perf_counter_ns()))
    var elapsed = value_of(run_on(program^, probe, 1, 64, ms(60_000), IORuntimeConfig()))
    check(probe[].get(ON_CALLER) == 1, "the interruptible call ran on the thread that handed worker 0 off")
    check(probe[].get(NAPPED) == 2, "the request ended the handle's sleep early")
    print("wstp_blocking: ms from start to the interruptible's cancellation:", elapsed, file=stderr)
    check(elapsed < 2_000, String("cancellation completed once the woken function returned: ms ", elapsed))


# ===--- Scenario 3: the cap overflows onto the root's pool ---=== #


@fieldwise_init
struct Hold(OnceThunk):
    """A call that holds for a while, counting calls in progress and handed-off ones."""
    var probe: Probe
    var hold_ms: Int
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        # The cap's count gives the calls handed off at once; with every call
        # in progress counted too, the difference ran on the root's pool.
        self.probe[].enter(RUNNING)
        sleep(Float64(self.hold_ms) / 2000.0)
        self.probe[].raise_to(HANDED_HIGH, self.probe[].handed_off())
        sleep(Float64(self.hold_ms) / 2000.0)
        _ = self.probe[].add(RUNNING, -1)
        return 1


def holds(probe: Probe, count: Int, hold_ms: Int) -> IO[Int, Int]:
    """Start `count` fibers that each make one held call, then join them all and sum their results."""
    return IO[Int, Int].blocking(Hold(probe.copy(), hold_ms)).start().flat_map(StartHolds(probe.copy(), count - 1, hold_ms, List[Fiber[Int, Int]]()))


@fieldwise_init
struct StartHolds(OnceUnary):
    var probe: Probe
    var left: Int
    var hold_ms: Int
    var fibers: List[Fiber[Int, Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.left == 0:
            return join_sum(self.fibers^, 0)
        return IO[Int, Int].blocking(Hold(self.probe.copy(), self.hold_ms)).start().flat_map(Self(self.probe^, self.left - 1, self.hold_ms, self.fibers^))


def join_sum(var fibers: List[Fiber[Int, Int]], total: Int) -> IO[Int, Int]:
    if not len(fibers):
        return IO[Int, Int].pure(total)
    var first = fibers.pop(0)
    return first^.join().flat_map(Sum(fibers^, total))


@fieldwise_init
struct Sum(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "every held call succeeds")
        return join_sum(self.rest^, self.total + outcome.take()._take_ok())


def cap_overflow():
    var probe = Probe(Words())
    check(value_of(run_on(holds(probe, 4, 300), probe, 1, 2, ms(60_000), IORuntimeConfig())) == 4, "every held call returns")
    check(probe[].get(HANDED_HIGH) == 2, String("the cap bounds the calls handed off at once: ", probe[].get(HANDED_HIGH)))
    check(probe[].get(RUNNING_HIGH) == 4, String("the calls beyond the cap run at once on the root's pool: ", probe[].get(RUNNING_HIGH)))


# ===--- Scenario 4: idle threads are reused, then retire ---=== #


@fieldwise_init
struct Count(OnceThunk):
    """Read the pool's thread cache: live and started threads."""
    var probe: Probe
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        ref core = _pool_at(self.probe[].get(POOL))[].blockers()[].owner.core[]
        self.probe[].set(LIVE, core.live())
        self.probe[].set(STARTED, core.started())
        return 0


@fieldwise_init
struct Then(OnceUnary):
    """Sequence: run `next` after the previous step's value."""
    var next: IO[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return self.next^


@fieldwise_init
struct ThenUnit(OnceUnary):
    var next: IO[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.next^


def nap(count: Int, var next: IO[Int, Int]) -> IO[Int, Int]:
    return IO[NoneType, Int].sleep(ms(count)).flat_map(ThenUnit(next^))


def reuse_and_retire():
    # One worker, so every call is made by whichever thread runs it:
    # 1. on the caller, which hands off to new thread A;
    # 2. on A, which hands off to new thread B, then idles after its call;
    # 3. after a pause, on B, which hands off to the idle A (reused), then idles;
    # then B, idle past the timeout, retires, and A still runs the worker.
    var probe = Probe(Words())
    var count = nap(600, IO[Int, Int].delay(Count(probe.copy())))
    var third = nap(50, IO[Int, Int].blocking(Hold(probe.copy(), 1)).flat_map(Then(count^)))
    var second = IO[Int, Int].blocking(Hold(probe.copy(), 1)).flat_map(Then(third^))
    var program = IO[Int, Int].blocking(Hold(probe.copy(), 1)).flat_map(Then(second^))
    _ = value_of(run_on(program^, probe, 1, 64, ms(150), IORuntimeConfig()))
    check(probe[].get(STARTED) == 2, String("an idle thread is reused instead of starting another: started ", probe[].get(STARTED)))
    check(probe[].get(LIVE) == 1, String("an idle thread retires after the idle timeout: live ", probe[].get(LIVE)))
    check(probe[].get(HANDED_HIGH) == 1, "each call handed off")


# ===--- Scenario 5: results and errors ---=== #


def six() -> Int:
    return 6


def refuse() raises Int -> Int:
    raise 4


@fieldwise_init
struct Seen(BorrowCallable):
    var offset: Int
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        return self.offset + (1 if handle.requested() else 0)


@fieldwise_init
struct Fails(BorrowCallable):
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Int

    def invoke(self, ref handle: Interruption) raises Int -> Int:
        raise 9


def results_and_errors():
    var probe = Probe(Words())
    check(value_of(run_on(IO[Int, Int].blocking(six), probe, 2, 64, ms(60_000), IORuntimeConfig())) == 6, "a blocking result returns")
    var failed = run_on(IO[Int, Int].blocking(refuse), probe, 2, 64, ms(60_000), IORuntimeConfig())
    check(Bool(failed) and not failed.value().is_ok() and failed.take()._take_err().errors.first() == 4, "a blocking error returns")
    check(value_of(run_on(IO[Int, Int].interruptible(Seen(10)), probe, 2, 64, ms(60_000), IORuntimeConfig())) == 10, "an interruptible result returns")
    var raised = run_on(IO[Int, Int].interruptible(Fails()), probe, 2, 64, ms(60_000), IORuntimeConfig())
    check(Bool(raised) and not raised.value().is_ok() and raised.take()._take_err().errors.first() == 9, "an interruptible error returns")


# ===--- Scenario 6: a configured pool is honored ---=== #


def configured_pool():
    var probe = Probe(Words())
    var config = IORuntimeConfig()
    try:
        config.blocking_pool = Optional(BlockingPool(max_workers=1))
    except:
        abort("wstp_blocking: could not configure a pool")
    check(value_of(run_on(holds(probe, 3, 30), probe, 2, 64, ms(60_000), config)) == 3, "every configured call returns")
    check(probe[].get(RUNNING_HIGH) == 1, "a configured pool of one worker still runs one call at a time")
    check(probe[].get(HANDED_HIGH) == 0, "no call hands off when a pool is configured")


def main():
    hand_off_progress()
    interruptible_cancel()
    cap_overflow()
    reuse_and_retire()
    results_and_errors()
    configured_pool()
    print("wstp_blocking: calls hand off their worker, wake on cancellation, overflow the cap, and retire idle threads")
