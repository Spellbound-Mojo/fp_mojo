"""Timers in each worker's own heap on the work-stealing pool.

Every part runs on a four-worker pool made for the part (`run_pool`, as
`_run_pooled` does), so it can read the pool's heaps and counts afterwards.

- **Sleeps across workers.** `SLEEPERS` fibers sleep `ROUNDS` times each for
  0.5 to 2.25 ms. No sleep ends before its deadline, and sleeps end on more
  than one worker.
- **Precision.** Those sleeps end within about 1 ms of their deadlines: the
  median lateness stays under `LATE_P50_NS`, and the 90th percentile under
  `LATE_P90_NS`, which leaves room for a busy host: qualification compiles
  beside the run, and four workers then share fewer cores (measured idle, the
  90th percentile stays under 0.2 ms).
- **Timeouts and cancellation across workers.** `CHURNERS` fibers run
  `CHURN` timeouts each. Half lose to their timeout, whose winner cancels a
  10 s sleep; the other half win at once and cancel the 10 s timeout. A
  canceled timer usually lives in another worker's heap, so cancellations
  arrive from other threads: the heaps count them, and must count some.
- **No leak of marked nodes.** While churning, the heap each fiber's worker
  owns stays below `HEAP_BOUND` entries, live and marked; afterwards every
  heap holds no pending timer and empties once its finished entries surface.
- **Stolen timers.** In `STEAL_RUNS` runs, spinners occupy workers right as
  sleepers' deadlines expire in those workers' heaps, while a ticker fiber
  keeps another worker waking and searching. Searching workers fire expired
  timers of busy workers (`stolen_timers`), and every sleeper wakes.
- **Descriptors across workers.** `WATCHERS` fibers each wait `WATCHES`
  times on their own pipe in the running worker's poller: half the waits
  find a byte the fiber wrote, half lose to a short timeout, which releases
  the registration, often from another worker. Releases from other threads
  happen, and once the pool stops, every worker's poller removes them all.
- **Cancellation from a foreign thread.** A root sleeping 30 s is canceled
  through its token from an OS thread outside the pool, and completes
  canceled at once.

The parts never assert which worker runs what, only bounds and counts.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import stderr
from std.time import monotonic, sleep
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Duration
from fp.effects.async_runtime.protocols import await_readable
from fp.effects._async.pool import _Pool, _pool_at, _pool_shard, _run_pooled, _submit_root
from fp.effects._async.polling import _Poller
from fp._internal.os import OSThread, Pipe, read, write
from fp._internal.waking import Signal
from fp._internal.time import Duration as _Duration

comptime WORKERS = 4
comptime SLEEPERS = 16
comptime ROUNDS = 40
comptime LATE_P50_NS = 1_500_000
comptime LATE_P90_NS = 10_000_000
comptime CHURNERS = 8
comptime CHURN = 150
comptime HEAP_BOUND = 128
comptime STEAL_RUNS = 12
comptime WATCHERS = 8
comptime WATCHES = 40
comptime BUCKETS = 64
"""Lateness histogram buckets of 100 µs; the last one collects the rest."""


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_worker_timers: ", message))


def now_ns() -> Int:
    return Int(monotonic())


def nanoseconds(count: Int) -> Duration:
    var duration = Duration()
    duration._nanoseconds = count
    return duration^


def spin(count: Int):
    var end = Int(monotonic()) + count
    while Int(monotonic()) < end:
        pass


struct Words(Movable):
    """Atomic words in their own allocation, shared by every thread."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]
    var count: Int

    def __init__(out self, count: Int):
        self.count = count
        self.words = unsafe_alloc[Atomic[Int]](count)
        for i in range(count):
            self.words.unsafe_offset(i).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        for i in range(self.count):
            self.words.unsafe_offset(i).unsafe_deinit_pointee()
        self.words.unsafe_free()

    @always_inline
    def at(self, index: Int) -> ref[MutUntrackedOrigin] Atomic[Int]:
        return self.words[unsafe_offset=index]

    def raise_to(self, index: Int, value: Int):
        var current = self.at(index).load()
        while value > current:
            if self.at(index).compare_exchange(current, value):
                return


# Statistics words: counts first, then per-worker wake counts, then the histogram.
comptime _COUNT = 0
comptime _EARLY = 1
comptime _MAX_LATE = 2
comptime _HEAP_MAX = 3
comptime _BAD = 4
comptime _WORKER_BASE = 8
comptime _HISTOGRAM = _WORKER_BASE + WORKERS
comptime _WORDS = _HISTOGRAM + BUCKETS


struct Stats(Copyable):
    """What fibers record: lateness of sleeps, the workers they ended on, heap sizes; copies share it."""
    var words: ArcPointer[Words]
    var target: Int

    def __init__(out self, target: Int):
        self.words = ArcPointer(Words(_WORDS))
        self.target = target

    def worker(self) -> Int:
        return _pool_shard(self.target)

    def late(self, deadline: Int):
        var lateness = now_ns() - deadline
        _ = self.words[].at(_COUNT).fetch_add(1)
        if lateness < 0:
            _ = self.words[].at(_EARLY).fetch_add(1)
            return
        self.words[].raise_to(_MAX_LATE, lateness)
        _ = self.words[].at(_HISTOGRAM + min(lateness // 100_000, BUCKETS - 1)).fetch_add(1)
        _ = self.words[].at(_WORKER_BASE + self.worker()).fetch_add(1)

    def heap(self):
        """Record the size of the heap the running worker owns; a read on its owner's thread."""
        var index = self.worker()
        var heap = _pool_at(self.target)[].opened_heap(index)
        if heap:
            self.words[].raise_to(_HEAP_MAX, heap.value()[].len())

    def percentile(self, fraction: Float64) -> Int:
        """The lateness, in nanoseconds, at or below which `fraction` of the sleeps ended (to 100 µs)."""
        var total = self.words[].at(_COUNT).load() - self.words[].at(_EARLY).load()
        var seen = 0
        for bucket in range(BUCKETS):
            seen += self.words[].at(_HISTOGRAM + bucket).load()
            if Float64(seen) >= fraction * Float64(total):
                return (bucket + 1) * 100_000
        return BUCKETS * 100_000


def run_pool(var program: IO[Int, Int], pool: ArcPointer[_Pool]) -> Int:
    """Run a root on `pool` with the caller as worker 0, as `_run_pooled` does, and shut the pool down."""
    var target = Int(Pointer(to=pool[]))
    pool[].enter(0)
    var handle = _submit_root(pool, program^, CancellationToken(), IORuntimeConfig())
    _ = pool[].run_worker(target, 0, False, handle.done_address())
    var outcome = handle^.take()
    pool[].shutdown()
    check(Bool(outcome) and outcome.value().is_ok(), "the root succeeds")
    return outcome.take()._take_ok()


def new_pool() -> ArcPointer[_Pool]:
    try:
        return ArcPointer(_Pool(WORKERS, 1))
    except:
        abort("wstp_worker_timers: could not create a pool")


def canceled_marks(pool: ArcPointer[_Pool]) -> Int:
    """Cancellations from threads other than a heap's owner, over every heap."""
    var total = 0
    for i in range(WORKERS):
        var heap = pool[].opened_heap(i)
        if heap:
            total += Int(heap.value()[]._shared[].canceled.load[ordering=Ordering.RELAXED]())
    return total


def heaps_settle(pool: ArcPointer[_Pool]):
    """After shutdown, as each heap's owner: nothing pending, and the finished entries leave."""
    for i in range(WORKERS):
        var opened = pool[].opened_heap(i)
        if not opened:
            continue
        var heap = opened.value()
        check(not heap[].poll_expired(UInt64.MAX), "no timer is still pending after its root")
        check(heap[].len() == 0, "every finished entry leaves its heap")


# ===--- Fibers started and joined in order ---=== #


@fieldwise_init
struct Spec(Copyable):
    """Which program a fiber runs: 0 sleeper, 1 churner, 2 spinner, 3 ticker, 4 one sleep, 5 watcher.

    A watcher's `index` packs its pipe's read end and write end, 16 bits each.
    """
    var kind: Int
    var index: Int
    var stats: Stats


def make(spec: Spec) -> IO[Int, Int]:
    if spec.kind == 0:
        return IO[Int, Int].pure(0).flat_map(SleepAgain(spec.index, ROUNDS, spec.stats.copy()))
    if spec.kind == 1:
        return IO[Int, Int].pure(0).flat_map(Churn(spec.index, CHURN, spec.stats.copy()))
    if spec.kind == 2:
        return IO[NoneType, Int].sleep(nanoseconds(1_000_000)).map(Spin(15_000_000))
    if spec.kind == 3:
        return IO[Int, Int].pure(0).flat_map(Tick(100))
    if spec.kind == 5:
        return IO[Int, Int].pure(0).flat_map(Watch(spec.index >> 16, spec.index & 0xFFFF, WATCHES))
    return IO[Int, Int].delay(now_ns).flat_map(SleepOnce(2_000_000, spec.stats.copy()))


@fieldwise_init
struct StartAll(OnceUnary):
    var specs: List[Spec]
    var started: Int
    var fibers: List[Fiber[Int, Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.started == len(self.specs):
            return join_sum(self.fibers^, 0)
        var next = make(self.specs[self.started])
        return next^.start().flat_map(Self(self.specs^, self.started + 1, self.fibers^))


def start_all(var specs: List[Spec]) -> IO[Int, Int]:
    var first = make(specs[0])
    return first^.start().flat_map(StartAll(specs^, 1, List[Fiber[Int, Int]]()))


def join_sum(var fibers: List[Fiber[Int, Int]], total: Int) -> IO[Int, Int]:
    if not len(fibers):
        return IO[Int, Int].pure(total)
    var first = fibers.pop(0)
    return first^.join().flat_map(JoinNext(fibers^, total))


@fieldwise_init
struct JoinNext(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "every fiber succeeds")
        return join_sum(self.rest^, self.total + outcome.take()._take_ok())


# ===--- Sleepers ---=== #


@fieldwise_init
struct SleepAgain(OnceUnary):
    var index: Int
    var left: Int
    var stats: Stats
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(done)
        var duration = 500_000 + ((self.index * 7 + self.left * 13) % 8) * 250_000
        return IO[Int, Int].delay(now_ns).flat_map(SleepRound(self.index, self.left, duration, self.stats^, done))


@fieldwise_init
struct SleepRound(OnceUnary):
    var index: Int
    var left: Int
    var duration: Int
    var stats: Stats
    var done: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var start: Int) -> IO[Int, Int]:
        return IO[NoneType, Int].sleep(nanoseconds(self.duration)).map(Late(start + self.duration, self.stats.copy(), self.done + 1)).flat_map(SleepAgain(self.index, self.left - 1, self.stats^))


@fieldwise_init
struct Late(OnceUnary):
    var deadline: Int
    var stats: Stats
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        self.stats.late(self.deadline)
        return self.value


@fieldwise_init
struct SleepOnce(OnceUnary):
    var duration: Int
    var stats: Stats
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var start: Int) -> IO[Int, Int]:
        return IO[NoneType, Int].sleep(nanoseconds(self.duration)).map(Late(start + self.duration, self.stats^, 1))


# ===--- Churners: timeouts that cancel timers ---=== #


@fieldwise_init
struct Churn(OnceUnary):
    var index: Int
    var left: Int
    var stats: Stats
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Int) -> IO[Int, Int]:
        self.stats.heap()
        if self.left == 0:
            return IO[Int, Int].pure(done)
        if (self.index + self.left) % 2 == 0:
            # The timeout wins: the 10 s sleep it races is canceled.
            var wait = 200_000 + (self.left % 5) * 100_000
            return IO[Int, Int].delay(now_ns).flat_map(TimeoutRound(wait, self.index, self.left, self.stats^, done))
        # The value wins at once: the 10 s timeout is canceled.
        return IO[Int, Int].pure(2).timeout_to(nanoseconds(10_000_000_000), IO[Int, Int].pure(1)).map(Expect(2, 0, done + 1)).flat_map(Self(self.index, self.left - 1, self.stats^))


@fieldwise_init
struct TimeoutRound(OnceUnary):
    var wait: Int
    var index: Int
    var left: Int
    var stats: Stats
    var done: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var start: Int) -> IO[Int, Int]:
        var slow = IO[NoneType, Int].sleep(nanoseconds(10_000_000_000)).map(Constant(0))
        return slow^.timeout_to(nanoseconds(self.wait), IO[Int, Int].pure(1)).map(Expect(1, start + self.wait, self.done + 1)).flat_map(Churn(self.index, self.left - 1, self.stats^))


@fieldwise_init
struct Constant(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Expect(OnceUnary):
    """Check a timeout's value, and that a fallback came no earlier than its deadline."""
    var expected: Int
    var deadline: Int
    var done: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        check(value == self.expected, "a timeout selects the expected side")
        check(now_ns() >= self.deadline, "a timeout never falls back before its deadline")
        return self.done


# ===--- Spinners and the ticker ---=== #


@fieldwise_init
struct Spin(OnceUnary):
    var duration: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        spin(self.duration)
        return 0


@fieldwise_init
struct Tick(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(0)
        return IO[NoneType, Int].sleep(nanoseconds(200_000)).map(Constant(0)).flat_map(Self(self.left - 1))


# ===--- Watchers: descriptor waits ---=== #


@fieldwise_init
struct Watch(OnceUnary):
    var reader: Int
    var writer: Int
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(done)
        var next = Self(self.reader, self.writer, self.left - 1)
        var wait = await_readable[Int](RawFileDescriptor(Int32(self.reader)))
        if self.left % 2 == 0:
            # A byte is there: the wait reports it, and the fiber reads it.
            return IO[Int, Int].pure(0).map(Put(self.writer)).flat_map(Then(wait^)).map(TakeByte(self.reader, done)).flat_map(next^)
        # Nothing comes: the timeout wins and the registration is released.
        return wait^.map(Constant(-1)).timeout_to(nanoseconds(300_000), IO[Int, Int].pure(0)).map(Plus(done + 1)).flat_map(next^)


@fieldwise_init
struct Put(OnceUnary):
    var fd: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var unit: Int) -> Int:
        var byte = List[UInt8](length=1, fill=7)
        try:
            check(write(Int32(self.fd), Span(byte)) == 1, "a watcher writes its byte")
        except:
            abort("wstp_worker_timers: a watcher's write failed")
        return 0


@fieldwise_init
struct Then(OnceUnary):
    var wait: IO[NoneType, Int]
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: Int) -> IO[NoneType, Int]:
        return self.wait^


@fieldwise_init
struct TakeByte(OnceUnary):
    var fd: Int
    var done: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        var byte = List[UInt8](length=1, fill=0)
        try:
            check(read(Int32(self.fd), Span(byte)) == 1, "a ready pipe holds the watcher's byte")
        except:
            abort("wstp_worker_timers: a watcher's read failed")
        return self.done + 1


@fieldwise_init
struct Plus(OnceUnary):
    var value: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var fallback: Int) -> Int:
        check(fallback == 0, "an unready pipe falls back to its timeout")
        return self.value


# ===--- Parts ---=== #


def sleeps():
    var pool = new_pool()
    var stats = Stats(Int(Pointer(to=pool[])))
    var specs = List[Spec]()
    for i in range(SLEEPERS):
        specs.append(Spec(0, i, stats.copy()))
    var total = run_pool(start_all(specs^), pool)
    check(total == SLEEPERS * ROUNDS, "every sleep completes")
    ref words = stats.words[]
    check(words.at(_COUNT).load() == SLEEPERS * ROUNDS, "every sleep is measured")
    check(words.at(_EARLY).load() == 0, "no sleep ends before its deadline")
    var workers = 0
    for i in range(WORKERS):
        if words.at(_WORKER_BASE + i).load() > 0:
            workers += 1
    check(workers > 1, "sleeps end on more than one worker")
    var p50 = stats.percentile(0.5)
    var p90 = stats.percentile(0.9)
    print("wstp_worker_timers: lateness p50 <=", p50 // 1000, "us, p90 <=", p90 // 1000, "us, max", words.at(_MAX_LATE).load() // 1000, "us, on", workers, "workers", file=stderr)
    check(p50 <= LATE_P50_NS and p90 <= LATE_P90_NS, "sleeps end within about 1 ms of their deadlines")
    heaps_settle(pool)
    print("sleeps across workers: ok")
    print("precision: ok")


def timeouts():
    var pool = new_pool()
    var stats = Stats(Int(Pointer(to=pool[])))
    var specs = List[Spec]()
    for i in range(CHURNERS):
        specs.append(Spec(1, i, stats.copy()))
    var total = run_pool(start_all(specs^), pool)
    check(total == CHURNERS * CHURN, "every timeout completes")
    var marks = canceled_marks(pool)
    var largest = stats.words[].at(_HEAP_MAX).load()
    print("wstp_worker_timers:", marks, "cancellations from other threads, largest owned heap", largest, file=stderr)
    check(marks > 0, "timers are canceled from other workers")
    check(largest <= HEAP_BOUND, "marked nodes do not accumulate in a heap")
    heaps_settle(pool)
    print("timeouts and cancellation across workers: ok")
    print("no leak of marked nodes: ok")


def stolen():
    var stolen = 0
    for _ in range(STEAL_RUNS):
        var pool = new_pool()
        var shared = Stats(Int(Pointer(to=pool[])))
        var specs = List[Spec]()
        specs.append(Spec(3, 0, shared.copy()))
        for i in range(3):
            specs.append(Spec(2, i, shared.copy()))
            specs.append(Spec(4, i, shared.copy()))
            specs.append(Spec(4, i + 3, shared.copy()))
        _ = run_pool(start_all(specs^), pool)
        check(shared.words[].at(_COUNT).load() == 6, "every sleeper wakes")
        check(shared.words[].at(_EARLY).load() == 0, "no sleeper wakes early")
        stolen += pool[].stolen_timers()
        heaps_settle(pool)
    print("wstp_worker_timers:", stolen, "timers fired by searching workers over", STEAL_RUNS, "runs", file=stderr)
    check(stolen > 0, "searching workers fire expired timers of busy workers")
    print("stolen timers: ok")


def descriptors():
    var pipes = List[Pipe]()
    var pool = new_pool()
    var stats = Stats(Int(Pointer(to=pool[])))
    var specs = List[Spec]()
    for _ in range(WATCHERS):
        try:
            pipes.append(Pipe.open_self_pipe())
        except:
            abort("wstp_worker_timers: could not open a pipe")
        var reader = Int(pipes[len(pipes) - 1].read_end.fd)
        var writer = Int(pipes[len(pipes) - 1].write_end.fd)
        specs.append(Spec(5, (reader << 16) | writer, stats.copy()))
    var total = run_pool(start_all(specs^), pool)
    check(total == WATCHERS * WATCHES, "every descriptor wait completes")
    var released = 0
    for i in range(WORKERS):
        var address = pool[]._slot(i)[].poller.load()
        if not address:
            continue
        var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)
        released += Int(poller[]._shared[].released[].value.load())
        # The workers are joined: this thread acts as the poller's owner.
        var ready = List[Signal]()
        try:
            _ = poller[].poll_deferred(Optional(_Duration()), ready)
        except:
            abort("wstp_worker_timers: a worker's poller failed")
        check(len(ready) == 0, "no wait is left to report")
        check(not poller[].has_registrations(), "every released registration is removed")
    print("wstp_worker_timers:", released, "descriptor registrations released from other threads", file=stderr)
    check(released > 0, "registrations are released from other workers")
    print("descriptors across workers: ok")


struct CancelLater(Movable):
    var token: CancellationToken
    var delay: Float64

    def __init__(out self, token: CancellationToken, delay: Float64):
        self.token = token.copy()
        self.delay = delay


def cancel_later(state: Pointer[CancelLater, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    sleep(state[].delay)
    state[].token.cancel()
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


def foreign_cancel():
    var token = CancellationToken()
    var thread: OSThread[CancelLater]
    try:
        thread = OSThread[CancelLater](ArcPointer(CancelLater(token, 0.005)), cancel_later)
    except:
        abort("wstp_worker_timers: could not start the canceling thread")
    var start = now_ns()
    var outcome = _run_pooled(IO[NoneType, Int].sleep(nanoseconds(30_000_000_000)).map(Constant(0)), token, IORuntimeConfig(), WORKERS)
    var elapsed = now_ns() - start
    # Joins the canceling thread.
    _ = thread^
    check(not outcome, "a root canceled from a foreign thread completes canceled")
    check(elapsed < 1_000_000_000, "a foreign cancellation ends a 30 s sleep at once")
    print("foreign cancellation: ok")


def main():
    sleeps()
    timeouts()
    stolen()
    descriptors()
    foreign_cancel()
