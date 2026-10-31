"""The blocking pool: IO.blocking and IO.interruptible on worker threads.

Blocking work runs on another thread while other fibers keep running; results
and errors return; a timeout waits for blocking; an interrupted function sees
the request and cancellation completes after it returns; idle workers are
reused and retired; the maximum holds under a burst; finishing a root waits
for its calls; a shared pool survives a root's finish; the last copy of a pool
dropped on its own worker detaches that worker; and every function, result
and error is destroyed exactly once, counted with a ledger.

`BLOCKING_SCALE` multiplies the burst and payload rounds for soaks.
"""
from std.atomic import Atomic
from std.ffi import external_call, c_int
from std.memory import ArcPointer
from std.os import abort, getenv
from std.time import monotonic, sleep
from fp.callables import OnceThunk, OnceUnary, BorrowCallable
from fp._internal.erased import _Erased
from fp._internal.os import getrusage, RUSAGE_SELF, Pipe, write as os_write
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Interruption, BlockingPool, IORuntimeConfig, Duration, run
from fp.effects._async.scheduling.blocking_pool import _RootBlocking, _WorkerContext


def check(condition: Bool, message: String):
    if not condition:
        abort(String("blocking pool: ", message))


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def scale() -> Int:
    var text = getenv("BLOCKING_SCALE")
    if not text:
        return 1
    try:
        return max(1, Int(text))
    except:
        return 1


def os_threads() -> Int:
    """The process's thread count, from /proc/self/status."""
    try:
        with open("/proc/self/status", "r") as f:
            for line in f.read().split("\n"):
                if line.startswith("Threads:"):
                    return Int(String(line[byte=8:].strip()))
    except:
        pass
    abort("blocking pool: cannot read the thread count")


def wait_until_threads(expected: Int) -> Bool:
    var deadline = Int(monotonic()) + 2_000_000_000
    while Int(monotonic()) < deadline:
        if os_threads() == expected:
            return True
        sleep(0.002)
    return False


def config_with(pool: BlockingPool) -> IORuntimeConfig:
    var config = IORuntimeConfig()
    config.blocking_pool = Optional(pool.copy())
    return config^


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("blocking pool: expected a success")
    return outcome.take()._take_ok()


# ===------------------------------------------------------------------=== #
# Another thread, while other fibers run
# ===------------------------------------------------------------------=== #


struct Shared(Movable):
    var flag: Atomic[Int]
    var worker: Atomic[UInt64]

    def __init__(out self):
        self.flag = Atomic(0)
        self.worker = Atomic(UInt64(0))


@fieldwise_init
struct AwaitFlag(OnceThunk):
    """On a worker: wait for a flag that only another fiber sets."""
    var shared: ArcPointer[Shared]
    comptime Out = Bool
    comptime Error = Never

    def call_once(deinit self) -> Bool:
        self.shared[].worker.store(thread_id())
        var deadline = Int(monotonic()) + 2_000_000_000
        while self.shared[].flag.load() == 0:
            if Int(monotonic()) > deadline:
                return False
            sleep(0.0005)
        return True


@fieldwise_init
struct SetFlag(OnceThunk):
    var shared: ArcPointer[Shared]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.shared[].flag.store(1)
        return 1


def other_thread():
    var shared = ArcPointer(Shared())
    var setter = IO[NoneType, Int].cede().flat_map(SetLater(shared.copy()))
    var both = value_of(run(IO[Bool, Int].blocking(AwaitFlag(shared.copy())).both(setter^)))
    check(both[0] and both[1] == 1, "another fiber ran while the blocking call waited")
    var worker = shared[].worker.load()
    check(worker != 0 and worker != thread_id(), "the blocking call ran on another thread")


@fieldwise_init
struct SetLater(OnceUnary):
    var shared: ArcPointer[Shared]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].delay(SetFlag(self.shared^))


# ===------------------------------------------------------------------=== #
# Results, errors, timeouts and interruption
# ===------------------------------------------------------------------=== #


def answer() -> Int:
    sleep(0.002)
    return 42


def refuse() raises Int -> Int:
    raise 7


def slow_answer() -> Int:
    sleep(0.05)
    return 5


def results_and_errors():
    check(value_of(run(IO[Int, Int].blocking(answer))) == 42, "a result returns")
    var failed = run(IO[Int, Int].blocking(refuse))
    check(Bool(failed) and failed.value().is_err(), "an error returns")
    check(failed.take()._take_err().errors.first() == 7, "the error is the function's")


def timeout_waits():
    var started = Int(monotonic())
    var raced = run(IO[Int, Int].blocking(slow_answer).timeout_to(ms(5), IO[Int, Int].pure(-1)))
    var elapsed = Int(monotonic()) - started
    check(elapsed >= 50_000_000, "a timeout waits for the blocking call to return")
    check(value_of(raced^) == 5, "timeout_to prefers the blocking call's drained result")


struct Probe(Movable):
    var saw: Atomic[Int]
    var returned: Atomic[Int]

    def __init__(out self):
        self.saw = Atomic(0)
        self.returned = Atomic(0)


@fieldwise_init
struct UntilInterrupted(BorrowCallable):
    """Poll the handle; after the request, keep working briefly, then return."""
    var probe: ArcPointer[Probe]
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        var deadline = Int(monotonic()) + 2_000_000_000
        while not handle.requested():
            if Int(monotonic()) > deadline:
                return -100
            sleep(0.0005)
        _ = self.probe[].saw.fetch_add(1)
        check(handle.requested(), "a request stays visible")
        sleep(0.02)
        self.probe[].returned.store(1)
        return 9


@fieldwise_init
struct Returned(OnceUnary):
    var probe: ArcPointer[Probe]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value * 1000 + self.probe[].returned.load()


def interruption():
    var probe = ArcPointer(Probe())
    var started = Int(monotonic())
    var program = IO[Int, Int].interruptible(UntilInterrupted(probe.copy())).timeout_to(ms(5), IO[Int, Int].pure(-1)).map(Returned(probe.copy()))
    var result = value_of(run(program^))
    var elapsed = Int(monotonic()) - started
    check(probe[].saw.load() == 1, "the interrupted function saw the request")
    check(result == -1000 + 1, "cancellation completed after the function returned, then the fallback ran")
    check(elapsed >= 25_000_000, "cancellation waited for the function")

    # Not canceled: the handle reports nothing and the value returns.
    check(value_of(run(IO[Int, Int].interruptible(quick))) == 0, "an uninterrupted call sees no request")


def sleeper(handle: Interruption) -> Int:
    # Woken by the request long before the ten seconds pass.
    return 1 if handle.sleep(ms(10_000)) else 2


def sleeps_out(handle: Interruption) -> Int:
    return 1 if handle.sleep(ms(5)) else 2


def interrupted_sleep():
    var started = Int(monotonic())
    var raced = value_of(run(IO[Int, Int].interruptible(sleeper).timeout_to(ms(5), IO[Int, Int].pure(-1))))
    var elapsed = Int(monotonic()) - started
    check(raced == -1, "the canceled sleeper's fallback runs")
    check(elapsed < 2_000_000_000, String("a wait through the handle wakes on the request, took ", elapsed))
    check(value_of(run(IO[Int, Int].interruptible(sleeps_out))) == 1, "an uninterrupted sleep runs its whole duration")


@fieldwise_init
struct AwaitPipe(BorrowCallable):
    """On a worker: wait for the pipe's read end, with or without a timeout."""
    var fd: Int
    var timeout_ms: Int
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Error

    def invoke(self, ref handle: Interruption) raises -> Int:
        var timeout = Optional[Duration](ms(self.timeout_ms)) if self.timeout_ms > 0 else None
        try:
            var ready = handle.await_readable(RawFileDescriptor(Int32(self.fd)), timeout)
            if ready:
                return 1
            return 2 if handle.requested() else 3
        except:
            raise Error("poll failed")


@fieldwise_init
struct AwaitWritable(BorrowCallable):
    var fd: Int
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Error

    def invoke(self, ref handle: Interruption) raises -> Int:
        try:
            return 1 if handle.await_writable(RawFileDescriptor(Int32(self.fd))) else 0
        except:
            raise Error("poll failed")


@fieldwise_init
struct WriteLater(OnceUnary):
    """From the root's thread, after a cede: make the pipe readable."""
    var fd: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Error]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Error]:
        return IO[Int, Error].delay(WriteByte(self.fd))


@fieldwise_init
struct WriteByte(OnceThunk):
    var fd: Int
    comptime Out = Int
    comptime Error = Error

    def call_once(deinit self) raises -> Int:
        var byte: List[UInt8] = [UInt8(7)]
        try:
            return os_write(c_int(self.fd), Span(byte))
        except:
            raise Error("write failed")


def error_value[T: Movable & Deinitable](var outcome: Outcome[T, Error]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("blocking pool: expected a success")
    return outcome.take()._take_ok()


def descriptor_waits() raises:
    var pipe = Pipe.open()
    var read_fd = Int(pipe.read_end.fd)
    var write_fd = Int(pipe.write_end.fd)
    # Timeout, then interruption, both on an empty pipe.
    check(error_value(run(IO[Int, Error].interruptible(AwaitPipe(read_fd, 5)))) == 3, "a descriptor wait times out")
    var started = Int(monotonic())
    var raced = error_value(run(IO[Int, Error].interruptible(AwaitPipe(read_fd, 0)).timeout_to(ms(5), IO[Int, Error].pure(-1))))
    check(raced == -1 and Int(monotonic()) - started < 2_000_000_000, "a descriptor wait wakes on the request")
    # Readiness that another fiber causes while the worker waits.
    var setter = IO[NoneType, Error].cede().flat_map(WriteLater(write_fd))
    var both = error_value(run(IO[Int, Error].interruptible(AwaitPipe(read_fd, 0)).both(setter^)))
    check(both[0] == 1 and both[1] == 1, "a descriptor wait wakes when the descriptor is ready")
    check(error_value(run(IO[Int, Error].interruptible(AwaitWritable(write_fd)))) == 1, "an empty pipe is writable")
    _ = pipe^


def quick(handle: Interruption) -> Int:
    return 1 if handle.requested() else 0


# ===------------------------------------------------------------------=== #
# Workers: reuse, retirement, the maximum
# ===------------------------------------------------------------------=== #


def nothing() -> Int:
    return 1


def reuse_and_retire() raises:
    var base = os_threads()
    var pool = BlockingPool(4, ms(40))
    for _ in range(10):
        check(value_of(run(IO[Int, Int].blocking(nothing), config_with(pool))) == 1, "a sequential call returns")
    check(pool._started() == 1, String("sequential calls reuse one worker, started ", pool._started()))
    check(pool._live() == 1, "the worker is still idle before the timeout")
    check(os_threads() == base + 1, "one worker thread exists")
    sleep(0.15)
    check(pool._live() == 0, "an idle worker retires after the timeout")
    check(value_of(run(IO[Int, Int].blocking(nothing), config_with(pool))) == 1, "a call after retirement starts a worker")
    check(pool._started() == 2, "a new worker started after retirement")
    # Idle workers park in their pollers: four idle workers use almost no CPU.
    var parked = BlockingPool(4, Duration.seconds(10))
    _ = value_of(run(IO[Int, Int].pure(0).flat_map(Burst(ArcPointer(Gauge()), 4)), config_with(parked)))
    var before = getrusage(RUSAGE_SELF)
    sleep(0.3)
    var after = getrusage(RUSAGE_SELF)
    var used = (after.user_nanoseconds + after.system_nanoseconds) - (before.user_nanoseconds + before.system_nanoseconds)
    check(parked._live() >= 2, "several idle workers are parked")
    check(used < 30_000_000, String("idle workers park without spinning, used ns: ", used))
    _ = parked^
    _ = pool^
    check(wait_until_threads(base), "dropping the last copy joins every worker")


struct Gauge(Movable):
    var running: Atomic[Int]
    var peak: Atomic[Int]
    var done: Atomic[Int]

    def __init__(out self):
        self.running = Atomic(0)
        self.peak = Atomic(0)
        self.done = Atomic(0)


@fieldwise_init
struct Measured(OnceThunk):
    var gauge: ArcPointer[Gauge]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        var now = self.gauge[].running.fetch_add(1) + 1
        var peak = self.gauge[].peak.load()
        while now > peak:
            if self.gauge[].peak.compare_exchange(peak, now):
                break
        sleep(0.003)
        _ = self.gauge[].running.fetch_sub(1)
        _ = self.gauge[].done.fetch_add(1)
        return 1


@fieldwise_init
struct Burst(OnceUnary):
    """Start one more blocking fiber, then the rest, joining them all."""
    var gauge: ArcPointer[Gauge]
    var remaining: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.remaining == 0:
            return IO[Int, Int].pure(total)
        var call = IO[Int, Int].blocking(Measured(self.gauge.copy()))
        var rest = IO[Int, Int].pure(total).flat_map(Burst(self.gauge.copy(), self.remaining - 1))
        return call^.both(rest^).map(Sum())


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


def maximum():
    var calls = 24 * scale()
    try:
        var pool = BlockingPool(3)
        var gauge = ArcPointer(Gauge())
        var total = value_of(run(IO[Int, Int].pure(0).flat_map(Burst(gauge.copy(), calls)), config_with(pool)))
        check(total == calls and gauge[].done.load() == calls, "every call of the burst ran")
        check(gauge[].peak.load() <= 3, String("at most the maximum ran at once, peak ", gauge[].peak.load()))
        check(gauge[].peak.load() >= 2, "the burst ran calls in parallel")
        check(pool._started() <= 3, "no more than the maximum started")
    except:
        abort("blocking pool: a valid pool")


# ===------------------------------------------------------------------=== #
# Payload ledger, root finish, shared pools
# ===------------------------------------------------------------------=== #


struct Ledger(Movable):
    var created: Atomic[Int]
    var destroyed: Atomic[Int]
    var on_workers: Atomic[Int]

    def __init__(out self):
        self.created = Atomic(0)
        self.destroyed = Atomic(0)
        self.on_workers = Atomic(0)


struct Counted(Movable):
    """A payload counted at creation and at its one destruction."""
    var ledger: ArcPointer[Ledger]
    var main: UInt64
    var value: Int
    var text: String

    def __init__(out self, ledger: ArcPointer[Ledger], main: UInt64, value: Int):
        self.ledger = ledger.copy()
        self.main = main
        self.value = value
        self.text = String("payload-", value, "-", "y" * 40)
        _ = self.ledger[].created.fetch_add(1)

    def __deinit__(deinit self):
        _ = self.ledger[].destroyed.fetch_add(1)
        if thread_id() != self.main:
            _ = self.ledger[].on_workers.fetch_add(1)


comptime CIO = IO[Counted, Counted]


@fieldwise_init
struct Produce(OnceThunk):
    """Own a counted payload; return another, or raise a third."""
    var held: Counted
    var fail: Bool
    comptime Out = Counted
    comptime Error = Counted

    def call_once(deinit self) raises Counted -> Counted:
        var ledger = self.held.ledger.copy()
        var main = self.held.main
        var value = self.held.value
        _ = self.held^
        if self.fail:
            raise Counted(ledger, main, -value)
        return Counted(ledger, main, value + 1)


@fieldwise_init
struct ProduceLate(BorrowCallable):
    """Return a payload only after the request: a late result, rejected on the worker."""
    var held: Counted
    comptime Payload = Interruption
    comptime Result = Counted
    comptime Failure = Counted

    def invoke(self, ref handle: Interruption) raises Counted -> Counted:
        while not handle.requested():
            sleep(0.0002)
        return Counted(self.held.ledger, self.held.main, self.held.value + 1)


def ledger_rounds():
    var ledger = ArcPointer(Ledger())
    var main = thread_id()
    var rounds = 50 * scale()
    for i in range(rounds):
        var ok = run(CIO.blocking(Produce(Counted(ledger, main, i), False)))
        check(Bool(ok) and ok.value().is_ok() and ok.take()._take_ok().value == i + 1, "the payload result returns")
        var bad = run(CIO.blocking(Produce(Counted(ledger, main, i), True)))
        check(Bool(bad) and bad.value().is_err(), "the payload error returns")
        var late = run(CIO.interruptible(ProduceLate(Counted(ledger, main, i))).timeout_to(ms(1), CIO.pure(Counted(ledger, main, 0))))
        check(Bool(late) and late.value().is_ok() and late.take()._take_ok().value == 0, "a canceled call's fallback runs")
        # Never run: the function is destroyed with the program.
        _ = CIO.blocking(Produce(Counted(ledger, main, i), False))
    check(ledger[].created.load() == ledger[].destroyed.load(), String("every payload destroyed exactly once: created ", ledger[].created.load(), ", destroyed ", ledger[].destroyed.load()))
    check(ledger[].on_workers.load() >= rounds, "late results were destroyed on workers")


@fieldwise_init
struct Linger(OnceThunk):
    """Return, then leave a payload for the worker to destroy after completing."""
    var held: Counted
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        var held = self.held^
        sleep(0.005)
        _ = held^
        return 1


def finish_waits():
    # Each run returns only after its root's calls finished on their workers.
    var ledger = ArcPointer(Ledger())
    var main = thread_id()
    for i in range(20):
        _ = run(IO[Int, Int].blocking(Linger(Counted(ledger, main, i))))
        check(ledger[].created.load() == ledger[].destroyed.load(), "the root finished after its calls")


def shared_pool() raises:
    var pool = BlockingPool(2, Duration.seconds(10))
    check(value_of(run(IO[Int, Int].blocking(nothing), config_with(pool))) == 1, "the first root's call")
    check(pool._live() == 1, "the shared pool survives the first root's finish")
    check(value_of(run(IO[Int, Int].blocking(nothing), config_with(pool))) == 1, "the second root's call")
    check(pool._started() == 1, "the second root reused the shared worker")


# ===------------------------------------------------------------------=== #
# The last copy dropped on the pool's own worker
# ===------------------------------------------------------------------=== #


struct Holder(Movable):
    var pool: BlockingPool
    var done: ArcPointer[Atomic[Int]]

    def __init__(out self, var pool: BlockingPool, done: ArcPointer[Atomic[Int]]):
        self.pool = pool^
        self.done = done.copy()


def run_holder(var body: _Erased, worker: _WorkerContext):
    var holder = body^.take[Holder]()
    sleep(0.005)
    var done = holder.done.copy()
    # The last copy of the pool goes here, on one of its own workers.
    _ = holder^
    done[].store(1)


def drop_on_worker() raises:
    var base = os_threads()
    var done = ArcPointer(Atomic[Int](0))
    var pool = BlockingPool(2)
    # The job runs on `pool` and holds `pool`'s only other copy.
    var on_pool = _RootBlocking(pool.copy())
    on_pool.submit(_Erased(Holder(pool^, done)), run_holder)
    on_pool^.finish()
    check(done[].load() == 1, "the call that dropped the last copy finished")
    check(wait_until_threads(base), "the detached worker exited on its own")


def main() raises:
    other_thread()
    results_and_errors()
    timeout_waits()
    interruption()
    interrupted_sleep()
    descriptor_waits()
    reuse_and_retire()
    maximum()
    ledger_rounds()
    finish_waits()
    shared_pool()
    drop_on_worker()
    print("blocking pool: other fibers run, results and errors, timeouts wait, interruption, handle sleeps and descriptor waits, reuse and retirement, the maximum, payload ledger, root finish, shared pools, last copy on a worker")
