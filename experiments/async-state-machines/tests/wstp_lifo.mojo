"""The work-stealing pool's LIFO slot: bounded, never stolen, flushed, and no wake lost.

A task woken by the task a worker is running goes into that worker's LIFO slot
and runs next on the same worker, after Tokio. Parts:

- **No starvation.** On one worker, a ping-pong pair passes a token through
  two one-slot queues, so every hop wakes the partner into the slot, while a
  third fiber on the ring cedes `STEPS` times. The pair gets at most
  `_MAX_LIFO_RUNS` slot runs in a row, so the ceding fiber finishes, with a
  bounded number of hops between its steps. Without the bound the pair
  starves it, which the execution timeout reports. The same program then
  runs on four workers.
- **Never stolen.** On four workers, in each of `ROUNDS` rounds, the root
  cedes, so that it starts the round below the slot's run bound, then starts
  two fibers and then a third, which leaves the first two on its ring
  (notifying a stealer) and the third in its slot, and then spins. The third
  fiber runs on the root's thread, after the spin: the stealers took from the
  ring, never from the slot.
- **Flushed.** On a one-worker pool driven by hand: `_flush_lifo` moves the
  slot's task to the ring, and a slot at its run bound sends its task to the
  ring before the worker looks for work, which then runs it.
- **Displaced work is picked up.** On four workers whose other workers
  parked, the root starts two CPU-bound fibers, so the first is displaced to
  its ring without a notify, then runs `BUSY` short steps without
  suspending. The displaced fiber starts on another thread before the root
  has taken `BUSY_BOUND` steps: the root's slice ends its run, and its
  requeue makes a second ring entry, which notifies a parked worker, which
  steals it while the displacing fiber spins in the slot.
- **No lost wake.** On four workers, `PAIRS` fiber pairs in a row, half of
  them ceding, then the ping-pong pair. A lost wake hangs.

The parts assert where a task ran only where the slot decides it.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv, stderr
from std.ffi import external_call
from std.time import monotonic
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Queue, Duration
from fp.effects._async.pool import _MAX_LIFO_RUNS, _Pool, _run_pooled, _submit_root

comptime WORKERS = 4
comptime STEPS = 200
comptime ROUNDS = 200
comptime SPIN_NS = 300_000
comptime PAIRS = 2000
comptime BUSY = 20_000
comptime BUSY_SPIN_NS = 2_000
# The root's run ends within one slice (1024 transitions by default), well
# under this many steps, even with a parked worker's wake latency.
comptime BUSY_BOUND = BUSY // 2
comptime SLOT_SPIN_NS = 50_000_000
# Hops the pair may make between two steps of the ceding fiber: its slot runs
# up to the bound, after each of the two partners leaves the ring.
comptime GAP_BOUND = 2 * (_MAX_LIFO_RUNS + 2)


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_lifo: ", message))


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


def thread_id() -> Int:
    return Int(external_call["pthread_self", UInt64]())


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


# ===--- A: a ping-pong pair cannot starve the ring ---=== #

# Words: 0 hops, 1 stop, 2 largest gap, 3 hops at the ceder's last step, 4 ceder steps.
comptime HOPS = 0
comptime STOP = 1
comptime GAP = 2
comptime LAST = 3
comptime CEDED = 4


@fieldwise_init
struct Pong(OnceUnary):
    """Take the token from this side's queue, then pass it on."""
    var side: Int
    var queues: List[Queue[Int]]
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.queues[self.side].take[Int]().flat_map(Bounce(self.side, self.queues^, self.words^))


@fieldwise_init
struct Bounce(OnceUnary):
    var side: Int
    var queues: List[Queue[Int]]
    var words: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var token: Int) -> IO[Int, Int]:
        var other = 1 - self.side
        if token < 0 or self.words[].at(STOP).load[ordering=Ordering.ACQUIRE]() != 0:
            # Release the partner, which waits on its queue, and finish.
            return self.queues[other].offer[Int](-1).map(Const(0))
        _ = self.words[].at(HOPS).fetch_add[ordering=Ordering.RELAXED](1)
        return self.queues[other].offer[Int](token + 1).flat_map(Pong(self.side, self.queues^, self.words^))


@fieldwise_init
struct Cede(OnceUnary):
    """One step of the ceding fiber: record the hops since its last step, then cede."""
    var left: Int
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var hops = self.words[].at(HOPS).load[ordering=Ordering.RELAXED]()
        var gap = hops - self.words[].at(LAST).load[ordering=Ordering.RELAXED]()
        self.words[].at(LAST).store[ordering=Ordering.RELAXED](hops)
        if gap > self.words[].at(GAP).load[ordering=Ordering.RELAXED]():
            self.words[].at(GAP).store[ordering=Ordering.RELAXED](gap)
        _ = self.words[].at(CEDED).fetch_add[ordering=Ordering.RELAXED](1)
        if self.left == 0:
            self.words[].at(STOP).store[ordering=Ordering.RELEASE](1)
            return IO[Int, Int].pure(0)
        return IO[NoneType, Int].cede().flat_map(Self(self.left - 1, self.words^))


@fieldwise_init
struct StartPong(OnceUnary):
    """Start side `side` of the pair, after the fibers already started."""
    var side: Int
    var fibers: List[Fiber[Int, Int]]
    var queues: List[Queue[Int]]
    var words: ArcPointer[Words]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.side == 2:
            # Serve the first hop, then wait for the ceder and the pair.
            return self.queues[0].offer[Int](0).flat_map(JoinAll(self.fibers^, 0))
        var pong = IO[NoneType, Int].pure(None).flat_map(Pong(self.side, self.queues.copy(), self.words.copy()))
        return pong^.start().flat_map(Self(self.side + 1, self.fibers^, self.queues^, self.words^))


@fieldwise_init
struct JoinAll(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return join_sum(self.fibers^, self.total)


def join_sum(var fibers: List[Fiber[Int, Int]], total: Int) -> IO[Int, Int]:
    if not len(fibers):
        return IO[Int, Int].pure(total)
    var first = fibers.pop(0)
    return first^.join_with_never().flat_map(JoinNext(fibers^, total))


@fieldwise_init
struct JoinNext(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return join_sum(self.rest^, self.total + value)


def ping_pong(workers: Int):
    var queues = List[Queue[Int]]()
    for _ in range(2):
        try:
            queues.append(Queue[Int](1))
        except:
            abort("wstp_lifo: queue")
    var words = ArcPointer(Words(5))
    # The ceder first, so the pair's starts leave it on the ring.
    var ceder = IO[NoneType, Int].pure(None).flat_map(Cede(STEPS, words.copy()))
    var program = ceder^.start().flat_map(StartPong(0, List[Fiber[Int, Int]](), queues^, words.copy()))
    var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), workers)
    check(Bool(outcome) and outcome.value().is_ok(), "the ping-pong root succeeds")
    check(words[].at(CEDED).load() == STEPS + 1, "the ceding fiber ran every step")
    if workers == 1:
        var hops = words[].at(HOPS).load()
        var gap = words[].at(GAP).load()
        check(hops >= STEPS, String("the pair hopped while the ceder ran (", hops, " hops)"))
        check(gap <= GAP_BOUND, String("the pair ran at most the slot's bound between the ceder's steps (gap ", gap, ")"))


# ===--- B: stealers never take from the slot ---=== #

# Words: 0 the root's thread, 1 spun, 2 the slot fiber's thread, 3 spun when it ran.
comptime ROOT_THREAD = 0
comptime SPUN = 1
comptime RAN_ON = 2
comptime RAN_AFTER = 3


@fieldwise_init
struct Mark(OnceUnary):
    """The slot fiber's body: record its thread and whether the root's spin was over."""
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        self.words[].at(RAN_ON).store[ordering=Ordering.RELAXED](thread_id())
        self.words[].at(RAN_AFTER).store[ordering=Ordering.RELAXED](self.words[].at(SPUN).load[ordering=Ordering.ACQUIRE]())
        return 1


@fieldwise_init
struct StartRound(OnceUnary):
    """Start the round's fibers one after another; the last goes into the slot, then the root spins."""
    var left: Int
    var started: Int
    var fibers: List[Fiber[Int, Int]]
    var words: ArcPointer[Words]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.started == 2:
            return IO[Int, Int].pure(0).flat_map(SpinRoot(self.left, self.fibers^, self.words^))
        var next: IO[Int, Int]
        if self.started == 1:
            next = IO[NoneType, Int].pure(None).map(Mark(self.words.copy()))
        else:
            next = IO[Int, Int].pure(1)
        return next^.start().flat_map(Self(self.left, self.started + 1, self.fibers^, self.words^))


@fieldwise_init
struct SpinRoot(OnceUnary):
    """Spin on the root's thread while stealers take the ring's entries, then join the round."""
    var left: Int
    var fibers: List[Fiber[Int, Int]]
    var words: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: Int) -> IO[Int, Int]:
        self.words[].at(ROOT_THREAD).store[ordering=Ordering.RELAXED](thread_id())
        var end = Int(monotonic()) + SPIN_NS
        while Int(monotonic()) < end:
            pass
        self.words[].at(SPUN).store[ordering=Ordering.RELEASE](1)
        return join_sum(self.fibers^, 0).flat_map(EndRound(self.left, self.words^))


@fieldwise_init
struct EndRound(OnceUnary):
    var left: Int
    var words: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        check(total == 3, "every fiber of the round ran once")
        check(self.words[].at(RAN_ON).load() == self.words[].at(ROOT_THREAD).load(), "the slot's fiber ran on the worker that woke it")
        check(self.words[].at(RAN_AFTER).load() == 1, "the slot's fiber ran only after its waker's run")
        self.words[].at(SPUN).store(0)
        if self.left == 1:
            return IO[Int, Int].pure(0)
        return round(self.left - 1, self.words^)


def round(left: Int, var words: ArcPointer[Words]) -> IO[Int, Int]:
    # The root may arrive from a slot, woken by the last round's joins, and
    # consecutive slot runs could then reach the bound, which would rightly
    # send the round's slot fiber to the ring. A cede first ends the run and
    # requeues the root to the ring, so whichever worker runs it next took it
    # through `_find`, with the count reset.
    return IO[NoneType, Int].cede().flat_map(BeginRound(left, words^))


@fieldwise_init
struct BeginRound(OnceUnary):
    var left: Int
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].pure(1).start().flat_map(StartRound(self.left, 0, List[Fiber[Int, Int]](), self.words^))


def never_stolen():
    var words = ArcPointer(Words(4))
    var outcome = _run_pooled(round(ROUNDS, words.copy()), CancellationToken(), IORuntimeConfig(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the stealing root succeeds")


# ===--- C: the slot is flushed to the ring ---=== #


def flushed():
    var pool: ArcPointer[_Pool]
    try:
        pool = ArcPointer(_Pool(1, 1))
    except:
        abort("wstp_lifo: pool")
    var target = Int(Pointer(to=pool[]))
    pool[].enter(0)
    var slot = pool[]._slot(0)
    # A root queued from worker 0 while it runs no task lands on the ring.
    var handle = _submit_root(pool, IO[Int, Int].pure(7), CancellationToken(), IORuntimeConfig())
    check(slot[].queue.len() == 1 and not slot[].lifo, "a push while no task runs goes to the ring")
    # `_flush_lifo` moves the slot's task to the ring.
    slot[].lifo = slot[].queue.dequeue()
    check(slot[].queue.is_empty() and Bool(slot[].lifo), "the task sits in the slot")
    pool[]._flush_lifo(target, slot)
    check(slot[].queue.len() == 1 and not slot[].lifo, "a flush moves the slot's task to the ring")
    # A slot at its run bound sends its task to the ring, which then runs it.
    slot[].lifo = slot[].queue.dequeue()
    slot[].lifo_runs = _MAX_LIFO_RUNS
    _ = pool[].run_worker(target, 0, False, handle.done_address())
    check(not slot[].lifo and slot[].lifo_runs == 0, "the bounded slot went through the ring, resetting the count")
    var outcome = handle^.take()
    pool[].shutdown()
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 7, "the flushed root ran")


# ===--- D: displaced work reaches parked workers ---=== #

# Words: 0 the root's steps, 1 the root's steps when the displaced fiber
# started, plus one, 2 its thread, 3 the thread whose ring it was displaced to.
comptime BUSY_STEPS = 0
comptime STARTED_AT = 1
comptime DISPLACED_ON = 2
comptime BUSY_THREAD = 3


@fieldwise_init
struct Displaced(OnceUnary):
    """The displaced fiber's body: record when and where it started."""
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        self.words[].at(DISPLACED_ON).store[ordering=Ordering.RELAXED](thread_id())
        self.words[].at(STARTED_AT).store[ordering=Ordering.RELEASE](self.words[].at(BUSY_STEPS).load[ordering=Ordering.ACQUIRE]() + 1)
        return 1


@fieldwise_init
struct Busy(OnceUnary):
    """`left` more short steps on the root, none of which suspends."""
    var left: Int
    var fibers: List[Fiber[Int, Int]]
    var words: ArcPointer[Words]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: Int) -> IO[Int, Int]:
        if self.left == 0:
            return join_sum(self.fibers^, 0)
        var end = Int(monotonic()) + BUSY_SPIN_NS
        while Int(monotonic()) < end:
            pass
        _ = self.words[].at(BUSY_STEPS).fetch_add[ordering=Ordering.RELEASE](1)
        return IO[Int, Int].pure(0).flat_map(Self(self.left - 1, self.fibers^, self.words^))


@fieldwise_init
struct StartDisplaced(OnceUnary):
    """Start the displaced fiber, then the one that displaces it, then go busy."""
    var fibers: List[Fiber[Int, Int]]
    var words: ArcPointer[Words]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if len(self.fibers) == 2:
            return IO[Int, Int].pure(0).flat_map(Busy(BUSY, self.fibers^, self.words^))
        # The displacing fiber spins on the root's worker after the root's
        # run, so the displaced one is left to the worker the requeue woke.
        # The root may move later, so its thread is the one displacing now.
        self.words[].at(BUSY_THREAD).store[ordering=Ordering.RELAXED](thread_id())
        return IO[NoneType, Int].pure(None).map(SpinBody()).start().flat_map(Self(self.fibers^, self.words^))


@fieldwise_init
struct SpinBody(OnceUnary):
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        var end = Int(monotonic()) + SLOT_SPIN_NS
        while Int(monotonic()) < end:
            pass
        return 1


@fieldwise_init
struct AfterQuiet(OnceUnary):
    var words: ArcPointer[Words]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var first = IO[NoneType, Int].pure(None).map(Displaced(self.words.copy()))
        return first^.start().flat_map(StartDisplaced(List[Fiber[Int, Int]](), self.words^))


def displaced_reaches_parked():
    var words = ArcPointer(Words(4))
    var quiet: Duration
    try:
        quiet = Duration.milliseconds(40)
    except:
        abort("wstp_lifo: duration")
    # Wake every worker once, then let them park before the displacement.
    var warm = IO[Int, Int].pure(0).flat_map(Pairs(8)).flat_map(Quiet(quiet^))
    var program = warm^.flat_map(AfterQuiet(words.copy()))
    var outcome = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 2, "the displacing root succeeds")
    var started = words[].at(STARTED_AT).load()
    print("wstp_lifo: displaced fiber started after", started - 1, "root steps", file=stderr)
    check(started > 0, "the displaced fiber ran")
    check(started - 1 < BUSY_BOUND, String("a parked worker took the displaced fiber within the bound (after ", started - 1, " root steps)"))
    check(words[].at(DISPLACED_ON).load() != words[].at(BUSY_THREAD).load(), "a parked worker, not the displacing one, ran the displaced fiber")


@fieldwise_init
struct Quiet(OnceUnary):
    var quiet: Duration
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var total: Int) -> IO[NoneType, Int]:
        return IO[NoneType, Int].sleep(self.quiet)


# ===--- E: no lost wake ---=== #


@fieldwise_init
struct StartRight(OnceUnary):
    var yields: Bool
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var left: Fiber[Int, Int]) -> IO[Int, Int]:
        var fibers = List[Fiber[Int, Int]]()
        fibers.append(left^)
        return child(2, self.yields).start().flat_map(JoinBoth(fibers^))


@fieldwise_init
struct JoinBoth(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var right: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(right^)
        return join_sum(self.fibers^, 0)


def child(value: Int, yields: Bool) -> IO[Int, Int]:
    if yields:
        return IO[NoneType, Int].cede().map(Const(value))
    return IO[Int, Int].pure(value)


@fieldwise_init
struct Pairs(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        var yields = self.left % 2 == 0
        var pair = child(1, yields).start().flat_map(StartRight(yields))
        return pair^.map(Plus(total)).flat_map(Pairs(self.left - 1))


def no_lost_wake():
    var outcome = _run_pooled(IO[Int, Int].pure(0).flat_map(Pairs(PAIRS)), CancellationToken(), IORuntimeConfig(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the pairs' root succeeds")
    check(outcome.take()._take_ok() == 3 * PAIRS, "every pair summed both children")
    ping_pong(WORKERS)


def main():
    # One part alone by name, for soaks; all by default.
    var part = String(argv()[1]) if len(argv()) > 1 else String("all")
    if part == "all" or part == "starve":
        ping_pong(1)
    if part == "all" or part == "stolen":
        never_stolen()
    if part == "all" or part == "flushed":
        flushed()
    if part == "all" or part == "displaced":
        displaced_reaches_parked()
    if part == "all" or part == "wakes":
        no_lost_wake()
    print("wstp_lifo: the LIFO slot is bounded, never stolen, flushed to the ring, reaches parked workers, and loses no wake")
