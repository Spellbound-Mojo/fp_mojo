"""No lost wake on the work-stealing pool, from foreign threads and from workers.

Every part runs on a four-worker pool through the private entry point
(`_run_pooled`); a lost wake hangs, which the execution timeout reports.

- **Foreign storm.** `FIBERS` fibers each await `ROUNDS` `IO.async`
  registrations in a row. Each registration goes into a mailbox that
  `PRODUCERS` OS threads drain, completing each after a random spin, so wakes
  arrive from foreign threads while workers run, search and park. Every
  registration completes exactly once.
- **Worker relay.** `RING` fibers pass a token around a ring of one-slot
  queues for `LAPS` laps: every hop is a wake from one fiber to another,
  usually on another worker, and most hops find the receiver parked.
- **Parked workers wake.** After a burst of parallel work, the root sleeps
  until every other worker parked, then starts CPU-bound fibers. The pool
  must deliver a wake (`_Pool.delivered_wakes`), and the burst must finish
  with every step run once and every value right. How many threads ran it
  is reported when only one did, not checked: on a loaded host the woken
  worker may get no processor before worker 0 runs the whole burst.

- **One worker.** `SINGLE_RUNS` runs on a one-worker pool, each with one
  fiber awaiting `ROUNDS` foreign completions that land after a random spin,
  racing the worker's park. The sole worker can never be refused permission
  to search, so it must park as a searcher and re-check the queues: a
  non-searcher's park skips the re-check, and a completion pushed just before
  it found the worker counted active and notified no one.

- **Late foreign completions.** In each of `LATE_RUNS` runs, a fiber posts
  an `IO.async` registration to a foreign thread and loses a race to a value
  that cedes once first, so the root completes, its scheduler closes and its pool
  shuts down while the completion may still be on its way. Completions land
  during and after that, with no crash, and every payload is destroyed
  exactly once.

The parts never assert which worker runs what, only counts and overlap.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv
from std.ffi import external_call
from std.time import monotonic, sleep
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import CancellationToken, Outcome, EffectFailure
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Completion, Queue, Duration, RaceResult
from fp.effects._async.pool import _Pool, _pool_at, _run_pooled, _submit_root
from fp._internal.os import OSThread

comptime WORKERS = 4
comptime FIBERS = 24
comptime ROUNDS = 150
comptime PRODUCERS = 3
comptime RING = 12
comptime LAPS = 60
comptime BURST = 8
comptime STEPS = 12
comptime SPIN = 30_000
comptime LATE_RUNS = 200
comptime SINGLE_RUNS = 40


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_wakes: ", message))


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


# ===--- A: the foreign storm ---=== #


struct Mailbox(Movable):
    """Registrations waiting for a producer, behind a spin lock; every field in its own allocation."""
    var lock: Pointer[Atomic[Int], MutUntrackedOrigin]
    var items: Pointer[List[Completion[Int, Int]], MutUntrackedOrigin]
    # 0: posted, 1: completed, 2: stop flag.
    var counts: Words

    def __init__(out self):
        self.lock = unsafe_alloc[Atomic[Int]](1)
        self.lock.unsafe_write(Atomic(0))
        self.items = unsafe_alloc[List[Completion[Int, Int]]](1)
        self.items.unsafe_write(List[Completion[Int, Int]]())
        self.counts = Words(3)

    def __deinit__(deinit self):
        self.items.unsafe_deinit_pointee()
        self.items.unsafe_free()
        self.lock.unsafe_deinit_pointee()
        self.lock.unsafe_free()

    def _acquire(self):
        while True:
            var expected = 0
            if self.lock[].compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](expected, 1):
                return
            sleep(0.0)

    def _release(self):
        self.lock[].store[ordering=Ordering.RELEASE](0)

    def put(self, var completion: Completion[Int, Int]):
        self._acquire()
        self.items[].append(completion^)
        self._release()
        _ = self.counts.at(0).fetch_add[ordering=Ordering.RELAXED](1)

    def take(self) -> Optional[Completion[Int, Int]]:
        self._acquire()
        var taken: Optional[Completion[Int, Int]] = None
        if len(self.items[]):
            taken = Optional(self.items[].pop(0))
        self._release()
        return taken^


struct Producer(Movable):
    var mailbox: ArcPointer[Mailbox]
    var seed: UInt64

    def __init__(out self, mailbox: ArcPointer[Mailbox], seed: UInt64):
        self.mailbox = mailbox.copy()
        self.seed = seed


def produce(state: Pointer[Producer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    var x = state[].seed
    while True:
        var item = state[].mailbox[].take()
        if not item:
            if state[].mailbox[].counts.at(2).load[ordering=Ordering.ACQUIRE]() != 0:
                break
            sleep(0.0)
            continue
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        var end = Int(monotonic()) + Int(x % 20_000)
        while Int(monotonic()) < end:
            pass
        var accepted = item.value().complete(Optional(Result[Int, EffectFailure[Int]](Ok(1))))
        check(accepted, "every registration accepts its one completion")
        _ = state[].mailbox[].counts.at(1).fetch_add[ordering=Ordering.RELAXED](1)
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


@fieldwise_init
struct Post(OnceUnary):
    var mailbox: ArcPointer[Mailbox]
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Int, Int]) -> NoneType:
        self.mailbox[].put(completion^)
        return None


@fieldwise_init
struct Await(OnceUnary):
    """Await one more foreign completion, or finish with the sum."""
    var left: Int
    var mailbox: ArcPointer[Mailbox]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].async_(Post(self.mailbox.copy())).map(Plus(total)).flat_map(Self(self.left - 1, self.mailbox^))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


@fieldwise_init
struct StartAll(OnceUnary):
    """Start `count` copies of a program made by `make`, then join them all and sum."""
    var started: Int
    var count: Int
    var fibers: List[Fiber[Int, Int]]
    var kind: Int
    var shared: ArcPointer[Mailbox]
    var gauge: ArcPointer[Words]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.started == self.count:
            return join_sum(self.fibers^, 0)
        return make(self.kind, self.started, self.shared, self.gauge).start().flat_map(Self(self.started + 1, self.count, self.fibers^, self.kind, self.shared^, self.gauge^))


def make(kind: Int, index: Int, shared: ArcPointer[Mailbox], gauge: ArcPointer[Words]) -> IO[Int, Int]:
    if kind == 0:
        return IO[Int, Int].pure(0).flat_map(Await(ROUNDS, shared.copy()))
    return IO[Int, Int].pure(0).flat_map(Spin(index, 0, gauge.copy()))


def start_all(kind: Int, count: Int, shared: ArcPointer[Mailbox], gauge: ArcPointer[Words]) -> IO[Int, Int]:
    return make(kind, 0, shared, gauge).start().flat_map(StartAll(1, count, List[Fiber[Int, Int]](), kind, shared.copy(), gauge.copy()))


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


def foreign_storm():
    var mailbox = ArcPointer(Mailbox())
    var gauge = ArcPointer(Words(2))
    var producers = List[OSThread[Producer]]()
    for i in range(PRODUCERS):
        try:
            producers.append(OSThread[Producer](ArcPointer(Producer(mailbox, UInt64(0x9E37 + i * 7919))), produce))
        except:
            abort("wstp_wakes: could not start a producer")
    var outcome = _run_pooled(start_all(0, FIBERS, mailbox, gauge), CancellationToken(), IORuntimeConfig(), WORKERS)
    mailbox[].counts.at(2).store[ordering=Ordering.RELEASE](1)
    producers.clear()
    check(Bool(outcome) and outcome.value().is_ok(), "the storm's root succeeds")
    check(outcome.take()._take_ok() == FIBERS * ROUNDS, "every foreign completion reached its fiber once")
    check(mailbox[].counts.at(0).load() == FIBERS * ROUNDS, "every registration was posted once")
    check(mailbox[].counts.at(1).load() == FIBERS * ROUNDS, "every registration was completed once")


def single_worker():
    var mailbox = ArcPointer(Mailbox())
    var gauge = ArcPointer(Words(2))
    var producer: OSThread[Producer]
    try:
        producer = OSThread[Producer](ArcPointer(Producer(mailbox, UInt64(0x51E6))), produce)
    except:
        abort("wstp_wakes: could not start the one-worker producer")
    for _ in range(SINGLE_RUNS):
        var outcome = _run_pooled(start_all(0, 1, mailbox, gauge), CancellationToken(), IORuntimeConfig(), 1)
        check(Bool(outcome) and outcome.value().is_ok(), "the one-worker root succeeds")
        check(outcome.take()._take_ok() == ROUNDS, "every foreign completion reached the one worker's fiber")
    mailbox[].counts.at(2).store[ordering=Ordering.RELEASE](1)
    _ = producer^
    check(mailbox[].counts.at(1).load() == SINGLE_RUNS * ROUNDS, "every one-worker registration was completed once")


# ===--- B: the worker relay ---=== #


@fieldwise_init
struct Hop(OnceUnary):
    """Take the token from this fiber's queue and pass it on, for `laps` laps."""
    var index: Int
    var laps: Int
    var queues: List[Queue[Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var passed: Int) -> IO[Int, Int]:
        if self.laps == 0:
            return IO[Int, Int].pure(passed)
        return self.queues[self.index].take[Int]().flat_map(Pass(self.index, self.laps, self.queues^, passed))


@fieldwise_init
struct Pass(OnceUnary):
    var index: Int
    var laps: Int
    var queues: List[Queue[Int]]
    var passed: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var token: Int) -> IO[Int, Int]:
        var next = (self.index + 1) % RING
        return self.queues[next].offer[Int](token + 1).map(Count(self.passed + 1)).flat_map(Hop(self.index, self.laps - 1, self.queues^))


@fieldwise_init
struct Count(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct RelayRest(OnceUnary):
    var started: Int
    var fibers: List[Fiber[Int, Int]]
    var queues: List[Queue[Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.started == RING:
            # Inject the token, then the last receiver's queue holds it at the end.
            return self.queues[0].offer[Int](0).flat_map(Finish(self.fibers^, self.queues^))
        return relay_fiber(self.started, self.queues).start().flat_map(Self(self.started + 1, self.fibers^, self.queues^))


@fieldwise_init
struct Finish(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var queues: List[Queue[Int]]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return join_sum(self.fibers^, 0).flat_map(Last(self.queues^))


@fieldwise_init
struct Last(OnceUnary):
    var queues: List[Queue[Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var hops: Int) -> IO[Int, Int]:
        check(hops == RING * LAPS, "every fiber passed the token once per lap")
        return self.queues[0].take[Int]()


def relay_fiber(index: Int, queues: List[Queue[Int]]) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Hop(index, LAPS, queues.copy()))


def worker_relay():
    var queues = List[Queue[Int]]()
    for _ in range(RING):
        try:
            queues.append(Queue[Int](1))
        except:
            abort("wstp_wakes: queue")
    var program = relay_fiber(0, queues).start().flat_map(RelayRest(1, List[Fiber[Int, Int]](), queues.copy()))
    var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the relay's root succeeds")
    check(outcome.take()._take_ok() == RING * LAPS, "the token made every hop")


# ===--- C: parked workers wake for new work ---=== #

# The gauge's words for this part: per thread slot, its pthread id, its steps
# and when it ran its first step; the pool's delivered wakes before the first
# quiet sleep, when the second burst starts and after it ends; the clock at
# the burst's start and end; and the parking counts at its start.
comptime G_THREAD = 2
comptime G_STEPS = G_THREAD + WORKERS
comptime G_FIRST = G_STEPS + WORKERS
comptime G_WAKES = G_FIRST + WORKERS
comptime G_CLOCK = G_WAKES + 3
comptime G_COUNTS = G_CLOCK + 2
comptime G_WORDS = G_COUNTS + 2
comptime QUIET_ROUNDS = 50
"""Quiet sleeps of 40 ms at most before the second burst, waiting for the pool to deliver a wake."""


def spin_bit(index: Int, step: Int) -> Int:
    """The bit one `Spin` step adds to its fiber's total."""
    var x = UInt64(index * 31 + step) + 1
    for _ in range(SPIN):
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
    return Int(x & 1)


def burst_total() -> Int:
    """What a burst of `BURST` `Spin` fibers sums to."""
    var total = 0
    for index in range(BURST):
        total += 1
        for step in range(STEPS):
            total += spin_bit(index, step)
    return total


@fieldwise_init
struct Spin(OnceUnary):
    var index: Int
    var step: Int
    var gauge: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.step == STEPS:
            return IO[Int, Int].pure(total + 1)
        # Record this thread in the first free of the gauge's thread slots, and count its step.
        var thread = Int(external_call["pthread_self", UInt64]())
        for i in range(WORKERS):
            var seen = self.gauge[].at(G_THREAD + i).load[ordering=Ordering.RELAXED]()
            if seen == 0:
                var expected = 0
                if self.gauge[].at(G_THREAD + i).compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](expected, thread):
                    self.gauge[].at(G_FIRST + i).store[ordering=Ordering.RELAXED](Int(monotonic()))
                    seen = thread
                else:
                    seen = expected
            if seen == thread:
                _ = self.gauge[].at(G_STEPS + i).fetch_add[ordering=Ordering.RELAXED](1)
                break
        var bit = spin_bit(self.index, self.step)
        return IO[Int, Int].pure(total + bit).flat_map(Self(self.index, self.step + 1, self.gauge^))


@fieldwise_init
struct Quiet(OnceUnary):
    """After the first burst: check it, reset the gauge, note the pool's delivered wakes, then sleep."""
    var target: Int
    var mailbox: ArcPointer[Mailbox]
    var gauge: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Int) -> IO[Int, Int]:
        check(first == burst_total(), "the first burst's fibers sum to their values")
        for i in range(G_THREAD, G_WORDS):
            self.gauge[].at(i).store[ordering=Ordering.RELEASE](0)
        self.gauge[].at(G_WAKES).store(_pool_at(self.target)[].delivered_wakes())
        return quiet(1, self.target, self.mailbox^, self.gauge^)


def quiet(round: Int, target: Int, var mailbox: ArcPointer[Mailbox], var gauge: ArcPointer[Words]) -> IO[Int, Int]:
    """Sleep long enough for the other workers to park; `Again` decides whether to sleep again."""
    var duration: Duration
    try:
        duration = Duration.milliseconds(40)
    except:
        abort("wstp_wakes: duration")
    return IO[NoneType, Int].sleep(duration).flat_map(Again(round, target, mailbox^, gauge^))


@fieldwise_init
struct Again(OnceUnary):
    """Sleep again until the pool delivered a wake, then record its counts and the clock and start the second burst.

    When the root's sleep ends, worker 0 leaves its park as a searcher, finds
    the root, and as the last searcher notifies: with the other workers
    parked, that claims and wakes one, which searches for the burst. A
    worker that had not parked yet takes the notify's place, so the sleep
    repeats, `QUIET_ROUNDS` times at most, until a wake was delivered.
    """
    var round: Int
    var target: Int
    var mailbox: ArcPointer[Mailbox]
    var gauge: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var wakes = _pool_at(self.target)[].delivered_wakes()
        if wakes == self.gauge[].at(G_WAKES).load() and self.round < QUIET_ROUNDS:
            return quiet(self.round + 1, self.target, self.mailbox^, self.gauge^)
        self.gauge[].at(G_WAKES + 1).store(wakes)
        self.gauge[].at(G_CLOCK).store(Int(monotonic()))
        self.gauge[].at(G_COUNTS).store(_pool_at(self.target)[].parking.active())
        self.gauge[].at(G_COUNTS + 1).store(_pool_at(self.target)[].parking.searching())
        return start_all(1, BURST, self.mailbox, self.gauge).map(Burst(self.target, self.gauge^))


@fieldwise_init
struct Burst(OnceUnary):
    """After the second burst joined: record the pool's delivered wakes and the clock again."""
    var target: Int
    var gauge: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var total: Int) -> Int:
        self.gauge[].at(G_WAKES + 2).store(_pool_at(self.target)[].delivered_wakes())
        self.gauge[].at(G_CLOCK + 1).store(Int(monotonic()))
        return total


def parked_wake():
    """Parked workers are woken for new work, which then completes with every value.

    The pool counts the wakes it delivers (`_Pool.delivered_wakes`: claims
    in `notify` that interrupted a parked worker or started one). Across the
    quiet sleep and the second burst at least one must be delivered: a lost
    wake, where the parking counts claim a searcher that does not exist,
    delivers none. Which threads then ran the burst is reported, not
    checked: on a loaded host the woken searcher may get no processor
    before worker 0 has run every step alone, and while it is counted
    searching the burst's pushes rightly wake no one else (in the soak,
    every single-thread run had delivered its wake).
    """
    var pool: ArcPointer[_Pool]
    try:
        pool = ArcPointer(_Pool(WORKERS, 1))
    except:
        abort("wstp_wakes: could not create a pool")
    var target = Int(Pointer(to=pool[]))
    var mailbox = ArcPointer(Mailbox())
    var gauge = ArcPointer(Words(G_WORDS))
    var program = start_all(1, BURST, mailbox, gauge).flat_map(Quiet(target, mailbox.copy(), gauge.copy()))
    # As `_run_pooled` does, on a pool this part owns so it can read the pool's counts.
    pool[].enter(0)
    var handle = _submit_root(pool, program^, CancellationToken(), IORuntimeConfig())
    _ = pool[].run_worker(target, 0, False, handle.done_address())
    var outcome = handle^.take()
    pool[].shutdown()
    check(Bool(outcome) and outcome.value().is_ok(), "the parked-wake root succeeds")
    check(outcome.take()._take_ok() == burst_total(), "the second burst's fibers sum to their values")
    var threads = 0
    var steps = 0
    for i in range(WORKERS):
        if gauge[].at(G_THREAD + i).load() != 0:
            threads += 1
        steps += gauge[].at(G_STEPS + i).load()
    check(steps == BURST * STEPS, "every step of the second burst ran once")
    var before = gauge[].at(G_WAKES + 1).load() - gauge[].at(G_WAKES).load()
    var during = gauge[].at(G_WAKES + 2).load() - gauge[].at(G_WAKES + 1).load()
    var start = gauge[].at(G_CLOCK).load()
    if before + during < 1 or threads <= 1:
        var report = String("wstp_wakes: parked: delivered wakes ", before, " in the quiet sleep, ", during, " in the burst; at its start ", gauge[].at(G_COUNTS).load(), " active, ", gauge[].at(G_COUNTS + 1).load(), " searching; burst ", (gauge[].at(G_CLOCK + 1).load() - start) // 1000, " us, threads")
        for i in range(WORKERS):
            if gauge[].at(G_THREAD + i).load() != 0:
                report += String(" [steps ", gauge[].at(G_STEPS + i).load(), ", first at ", (gauge[].at(G_FIRST + i).load() - start) // 1000, " us]")
        print(report)
    check(before + during >= 1, "a parked worker was woken for the second burst")


# ===--- D: late foreign completions ---=== #


struct Tracked(Movable):
    """A payload counted when made and when destroyed (words 0 and 1)."""
    var counts: ArcPointer[Words]

    def __init__(out self, counts: ArcPointer[Words]):
        self.counts = counts.copy()
        _ = self.counts[].at(0).fetch_add(1)

    def __deinit__(deinit self):
        _ = self.counts[].at(1).fetch_add(1)


struct LateBox(Movable):
    """Registrations waiting for the late producer, behind a spin lock, and its stop flag."""
    var lock: Pointer[Atomic[Int], MutUntrackedOrigin]
    var items: Pointer[List[Completion[Tracked, Int]], MutUntrackedOrigin]
    var stop: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.lock = unsafe_alloc[Atomic[Int]](1)
        self.lock.unsafe_write(Atomic(0))
        self.items = unsafe_alloc[List[Completion[Tracked, Int]]](1)
        self.items.unsafe_write(List[Completion[Tracked, Int]]())
        self.stop = unsafe_alloc[Atomic[Int]](1)
        self.stop.unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        self.items.unsafe_deinit_pointee()
        self.items.unsafe_free()
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

    def put(self, var completion: Completion[Tracked, Int]):
        self._acquire()
        self.items[].append(completion^)
        self.lock[].store[ordering=Ordering.RELEASE](0)

    def take(self) -> Optional[Completion[Tracked, Int]]:
        self._acquire()
        var taken: Optional[Completion[Tracked, Int]] = None
        if len(self.items[]):
            taken = Optional(self.items[].pop(0))
        self.lock[].store[ordering=Ordering.RELEASE](0)
        return taken^


struct LateProducer(Movable):
    var box: ArcPointer[LateBox]
    var counts: ArcPointer[Words]

    def __init__(out self, box: ArcPointer[LateBox], counts: ArcPointer[Words]):
        self.box = box.copy()
        self.counts = counts.copy()


def produce_late(state: Pointer[LateProducer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    var x = UInt64(0x1A7E)
    while True:
        var item = state[].box[].take()
        if not item:
            if state[].box[].stop[].load[ordering=Ordering.ACQUIRE]() != 0:
                break
            sleep(0.0)
            continue
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        # Land before, during, or well after the root's completion.
        var end = Int(monotonic()) + Int(x % 200_000)
        while Int(monotonic()) < end:
            pass
        # Accepted or rejected, the payload is destroyed exactly once.
        _ = item.value().complete(Optional(Result[Tracked, EffectFailure[Int]](Ok(Tracked(state[].counts)))))
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


@fieldwise_init
struct PostLate(OnceUnary):
    var box: ArcPointer[LateBox]
    comptime Arg = Completion[Tracked, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Tracked, Int]) -> NoneType:
        self.box[].put(completion^)
        return None


@fieldwise_init
struct Drop(OnceUnary):
    comptime Arg = Tracked
    comptime Out = Int

    def call_once(deinit self, var payload: Tracked) -> Int:
        return 2


@fieldwise_init
struct Settled(OnceUnary):
    comptime Arg = RaceResult[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var result: RaceResult[Int, Int]) -> Int:
        return 1


def late_completions():
    var box = ArcPointer(LateBox())
    var counts = ArcPointer(Words(2))
    var producer: OSThread[LateProducer]
    try:
        producer = OSThread[LateProducer](ArcPointer(LateProducer(box, counts)), produce_late)
    except:
        abort("wstp_wakes: could not start the late producer")
    for _ in range(LATE_RUNS):
        var waiting = IO[Tracked, Int].async_(PostLate(box.copy())).map(Drop())
        # The winner cedes once, so the waiting side runs and posts first;
        # a pool's LIFO slot would otherwise run the winner straight away.
        var winner = IO[NoneType, Int].cede().map(Count(1))
        var program = waiting^.race(winner^).map(Settled())
        var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), WORKERS)
        check(Bool(outcome) and outcome.value().is_ok(), "the late round's root succeeds")
    box[].stop[].store[ordering=Ordering.RELEASE](1)
    _ = producer^
    check(counts[].at(0).load() > 0, "some registrations reached the foreign thread")
    check(counts[].at(0).load() == counts[].at(1).load(), "every late payload was destroyed exactly once")


def main():
    # One part alone by name, for soaks; all three by default.
    var part = String(argv()[1]) if len(argv()) > 1 else String("all")
    if part == "all" or part == "storm":
        foreign_storm()
    if part == "all" or part == "relay":
        worker_relay()
    if part == "all" or part == "parked":
        parked_wake()
    if part == "all" or part == "single":
        single_worker()
    if part == "all" or part == "late":
        late_completions()
    print("wstp_wakes: foreign and worker wakes are never lost, and parked workers wake for new work")
