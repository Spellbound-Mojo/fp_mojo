"""Randomized operation mixes on both profiles, with exactly-once accounting.

Each round draws a random program tree from the seed, which the program prints
first, and runs it twice through the public `run`: on a four-worker
work-stealing pool, then on the current-thread profile. Its nodes:

- **Leaves:** a pure value, a cede, a sleep of up to 1.5 ms (timers), a
  blocking call that returns a tracked payload (the blocking hand-off on the
  pool, the root's `BlockingPool` otherwise), an `IO.async` registration that
  one of two foreign OS threads completes with a tracked payload after a
  random spin (foreign wakes), a CPU spin, a failure caught by `attempt`, and
  an unjoined fiber that fails, which the reporter sees.
- **Composites:** `both`, `race`, a started fiber that is joined (spawn and
  join), a started fiber that is canceled and then joined, and
  `par_traverse` over two to four children.

Invariants, checked on both profiles:

- the program's value equals the plan's value, computed from the tree alone;
- every race has one winner, carrying that side's own value;
- a canceled fiber either was canceled or succeeded with its own value;
- every joined fiber succeeds with its own value, and `par_traverse` keeps
  source order;
- every tracked payload is destroyed exactly once, once the foreign threads
  finished their completions, including those that lost to a cancellation;
- every failure is observed exactly once. An unjoined fiber's failure is
  reported once. A failure caught by `attempt` is handled once, except below
  a race or a cancellation: `attempt` leaves a failure raised during its
  fiber's cancellation terminal, so it may instead surface once as the error
  of the nearest race (which keeps a loser's errors), of a canceled fiber's
  join, or of a join that took it while its joiner was being canceled, or be
  reported once when its fiber's join was canceled first. No failure may reach
  a round's root.

Usage: `wstp_stress [seed [rounds]]`; seed 1 and `ROUNDS` rounds by default,
so qualification's output is fixed. Soaks pass their own seeds. Every check
names the seed and round in its abort message.
"""
from std.atomic import Atomic, Ordering
from std.ffi import c_int, external_call
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv, stderr
from std.time import monotonic, sleep
from fp.algebra import par_traverse
from fp.callables import OnceThunk, OnceUnary, Unary
from fp.data import Left, Right, Result, Ok
from fp.effects import EffectFailure, Outcome, ThreadTransferable
from fp.effects.async_runtime import IO, Fiber, Completion, Duration, IORuntimeConfig, Profile, RaceResult, run
from fp._internal.os import OSThread, Pipe

comptime WORKERS = 4
comptime ROUNDS = 40
comptime MAX_DEPTH = 5
comptime MAX_NODES = 80
comptime MAX_FAILURES = 64
comptime PRODUCERS = 2
comptime REPORT_FD = 78
"""The descriptor the reporter writes to: the pipe's write end, duplicated there."""
comptime CODE_BASE = 1_000_000
"""Failure codes are `CODE_BASE + id`, so a report line names its failure."""

# Node kinds.
comptime PURE = 0
comptime CEDE = 1
comptime SLEEP = 2
comptime BLOCK = 3
comptime FOREIGN = 4
comptime SPIN = 5
comptime FAIL = 6
comptime ORPHAN = 7
comptime BOTH = 8
comptime RACE = 9
comptime JOIN = 10
comptime CANCEL = 11
comptime PAR = 12

# Ledger words: payloads made and destroyed, completions posted and finished,
# the producers' stop flag, fibers canceled before finishing, race winners by
# side, then raised and handled counts per failure.
comptime MADE = 0
comptime DESTROYED = 1
comptime POSTED = 2
comptime FINISHED = 3
comptime STOP = 4
comptime CANCELED = 5
comptime LEFT_WINS = 6
comptime RIGHT_WINS = 7
comptime RAISED = 8
comptime HANDLED = RAISED + MAX_FAILURES
comptime WORDS = HANDLED + MAX_FAILURES


def fail(message: String):
    abort(String("wstp_stress: ", message))


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

    def bump(self, index: Int):
        _ = self.at(index).fetch_add[ordering=Ordering.RELAXED](1)

    def get(self, index: Int) -> Int:
        return self.at(index).load[ordering=Ordering.ACQUIRE]()

    def reset(self, start: Int, end: Int):
        for i in range(start, end):
            self.at(i).store[ordering=Ordering.RELEASE](0)


struct Tracked(Movable):
    """A payload counted when made and when destroyed, carrying the value it stands for."""
    var ledger: ArcPointer[Words]
    var value: Int

    def __init__(out self, ledger: ArcPointer[Words], value: Int):
        self.ledger = ledger.copy()
        self.value = value
        self.ledger[].bump(MADE)

    def __deinit__(deinit self):
        self.ledger[].bump(DESTROYED)


# ===--- The foreign producers ---=== #


struct Mailbox(Movable):
    """Registrations waiting for a producer, with the value each must carry, behind a spin lock."""
    var lock: Pointer[Atomic[Int], MutUntrackedOrigin]
    var items: Pointer[List[Completion[Tracked, Int]], MutUntrackedOrigin]
    var values: Pointer[List[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.lock = unsafe_alloc[Atomic[Int]](1)
        self.lock.unsafe_write(Atomic(0))
        self.items = unsafe_alloc[List[Completion[Tracked, Int]]](1)
        self.items.unsafe_write(List[Completion[Tracked, Int]]())
        self.values = unsafe_alloc[List[Int]](1)
        self.values.unsafe_write(List[Int]())

    def __deinit__(deinit self):
        self.items.unsafe_deinit_pointee()
        self.items.unsafe_free()
        self.values.unsafe_deinit_pointee()
        self.values.unsafe_free()
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

    def put(self, var completion: Completion[Tracked, Int], value: Int):
        self._acquire()
        self.items[].append(completion^)
        self.values[].append(value)
        self._release()

    def take(self) -> Optional[Tuple[Completion[Tracked, Int], Int]]:
        self._acquire()
        var taken: Optional[Tuple[Completion[Tracked, Int], Int]] = None
        if len(self.items[]):
            taken = Optional(Tuple(self.items[].pop(0), self.values[].pop(0)))
        self._release()
        return taken^


struct Shared(Movable):
    """What every node of a run reaches: the ledger and the producers' mailbox."""
    var ledger: ArcPointer[Words]
    var mailbox: ArcPointer[Mailbox]

    def __init__(out self):
        self.ledger = ArcPointer(Words(WORDS))
        self.mailbox = ArcPointer(Mailbox())


struct Producer(Movable):
    var shared: ArcPointer[Shared]
    var seed: UInt64

    def __init__(out self, shared: ArcPointer[Shared], seed: UInt64):
        self.shared = shared.copy()
        self.seed = seed


def produce(state: Pointer[Producer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    var x = state[].seed | 1
    while True:
        var item = state[].shared[].mailbox[].take()
        if not item:
            if state[].shared[].ledger[].get(STOP) != 0:
                break
            sleep(0.0)
            continue
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        var end = Int(monotonic()) + Int(x % 40_000)
        while Int(monotonic()) < end:
            pass
        var pair = item.take()
        var value = pair[1]
        # Accepted, or rejected after a cancellation: the payload is destroyed once either way.
        _ = pair[0].complete(Optional(Result[Tracked, EffectFailure[Int]](Ok(Tracked(state[].shared[].ledger, value)))))
        state[].shared[].ledger[].bump(FINISHED)
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


# ===--- The reporter ---=== #


def report(line: String):
    """Called from any thread, at once from several; each line is one write."""
    var text = line + "\n"
    var bytes = text.as_bytes()
    if external_call["write", Int](c_int(REPORT_FD), bytes.unsafe_ptr(), len(bytes)) != len(bytes):
        abort("wstp_stress: the report pipe is full")


def read_reports(pipe: Pipe) -> List[String]:
    var lines = List[String]()
    var text = String()
    var buffer = List[UInt8](length=4096, fill=0)
    while True:
        var count = external_call["read", Int](pipe.read_end.fd, buffer.unsafe_ptr(), 4096)
        if count <= 0:
            break
        for i in range(count):
            if buffer[i] == UInt8(ord("\n")):
                lines.append(text)
                text = String()
            else:
                text += chr(Int(buffer[i]))
    return lines^


# ===--- Plans ---=== #


struct Random(Movable):
    var x: UInt64

    def __init__(out self, seed: UInt64):
        self.x = seed * 0x9E3779B97F4A7C15 + 0x2545F4914F6CDD1D

    def next(mut self) -> UInt64:
        self.x ^= self.x << 13
        self.x ^= self.x >> 7
        self.x ^= self.x << 17
        return self.x

    def below(mut self, n: Int) -> Int:
        return Int(self.next() % UInt64(n))


struct Plan(Movable):
    """A program tree, immutable once drawn; children are node indices, and `value` is each node's own datum."""
    var kind: List[Int]
    var value: List[Int]
    var first: List[Int]
    var second: List[Int]
    var kids: List[List[Int]]
    # Whether a race or a cancellation sits above the node, which may stop it midway.
    var stoppable: List[Bool]
    var failures: Int

    def __init__(out self):
        self.kind = List[Int]()
        self.value = List[Int]()
        self.first = List[Int]()
        self.second = List[Int]()
        self.kids = List[List[Int]]()
        self.stoppable = List[Bool]()
        self.failures = 0

    def add(mut self, kind: Int, value: Int, stoppable: Bool) -> Int:
        self.kind.append(kind)
        self.value.append(value)
        self.first.append(-1)
        self.second.append(-1)
        self.kids.append(List[Int]())
        self.stoppable.append(stoppable)
        return len(self.kind) - 1

    def fail_ids(self, node: Int, mut ids: List[Int]):
        """The failure ids of the `attempt`-caught failures in the node's subtree."""
        var pending = List[Int]()
        pending.append(node)
        while len(pending):
            var at = pending.pop()
            if self.kind[at] == FAIL:
                ids.append(self.value[at])
            if self.first[at] >= 0:
                pending.append(self.first[at])
            if self.second[at] >= 0:
                pending.append(self.second[at])
            for kid in self.kids[at]:
                pending.append(kid)

    def expected(self, node: Int) -> Int:
        """The node's value, from the tree alone."""
        var kind = self.kind[node]
        if kind == BOTH:
            return self.expected(self.first[node]) + self.expected(self.second[node])
        if kind == JOIN:
            return self.expected(self.first[node])
        if kind == RACE or kind == CANCEL:
            return 1
        if kind == PAR:
            var total = 0
            for kid in self.kids[node]:
                total += self.expected(kid)
            return total
        if kind == FAIL or kind == ORPHAN:
            return 0
        return self.value[node]


def draw(mut plan: Plan, mut random: Random, depth: Int, stoppable: Bool) -> Int:
    var composite = depth == 0 or depth < MAX_DEPTH and len(plan.kind) < MAX_NODES and random.below(10) < 7
    if not composite:
        var roll = random.below(12)
        var kind = PURE if roll < 2 else CEDE if roll < 3 else SLEEP if roll < 5 else BLOCK if roll < 7 else FOREIGN if roll < 9 else SPIN if roll < 10 else FAIL if roll < 11 else ORPHAN
        var value = 1 + random.below(1000)
        if kind == SLEEP:
            value = 1 + random.below(1500)
        if kind == FAIL or kind == ORPHAN:
            if plan.failures >= MAX_FAILURES:
                kind = PURE
            else:
                value = plan.failures
                plan.failures += 1
        return plan.add(kind, value, stoppable)
    var roll = random.below(9)
    var kind = BOTH if roll < 2 else RACE if roll < 4 else JOIN if roll < 6 else CANCEL if roll < 8 else PAR
    var node = plan.add(kind, random.below(2), stoppable)
    var below = stoppable or kind == RACE or kind == CANCEL
    if kind == PAR:
        var count = 2 + random.below(3)
        for _ in range(count):
            var kid = draw(plan, random, depth + 1, below)
            plan.kids[node].append(kid)
        return node
    var first = draw(plan, random, depth + 1, below)
    plan.first[node] = first
    if kind == BOTH or kind == RACE:
        var second = draw(plan, random, depth + 1, below)
        plan.second[node] = second
    return node


# ===--- Building a plan's program ---=== #


@fieldwise_init
struct Context(Copyable):
    """A node's view of the round: the plan, the shared ledger and mailbox, and the seed and round for messages."""
    var plan: ArcPointer[Plan]
    var shared: ArcPointer[Shared]
    var label: String


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Spin(OnceThunk):
    var value: Int
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        var end = Int(monotonic()) + 2_000 + (self.value % 20) * 1_000
        while Int(monotonic()) < end:
            pass
        return self.value


@fieldwise_init
struct MakeTracked(OnceThunk):
    """A blocking call: hold briefly, then return a payload made on the calling thread."""
    var ledger: ArcPointer[Words]
    var value: Int
    comptime Out = Tracked
    comptime Error = Never

    def call_once(deinit self) -> Tracked:
        var end = Int(monotonic()) + (self.value % 50) * 1_000
        while Int(monotonic()) < end:
            pass
        return Tracked(self.ledger, self.value)


@fieldwise_init
struct Unwrap(OnceUnary):
    """Check a payload's value and destroy it."""
    var value: Int
    var label: String
    comptime Arg = Tracked
    comptime Out = Int

    def call_once(deinit self, var payload: Tracked) -> Int:
        if payload.value != self.value:
            fail(self.label + ": a payload carries another node's value")
        return self.value


@fieldwise_init
struct Post(OnceUnary):
    var mailbox: ArcPointer[Mailbox]
    var ledger: ArcPointer[Words]
    var value: Int
    comptime Arg = Completion[Tracked, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Tracked, Int]) -> NoneType:
        self.ledger[].bump(POSTED)
        self.mailbox[].put(completion^, self.value)
        return None


@fieldwise_init
struct Raise(OnceThunk):
    """Count a failure as raised, then raise it."""
    var ledger: ArcPointer[Words]
    var id: Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call_once(deinit self) -> IO[Int, Int]:
        self.ledger[].bump(RAISED + self.id)
        return IO[Int, Int].raise_error(CODE_BASE + self.id)


@fieldwise_init
struct Handle(OnceUnary):
    """An `attempt`'s handler: the failure must be its own, and it is handled once."""
    var ledger: ArcPointer[Words]
    var id: Int
    var label: String
    comptime Arg = Result[Int, EffectFailure[Int]]
    comptime Out = Int

    def call_once(deinit self, var result: Result[Int, EffectFailure[Int]]) -> Int:
        if result.is_ok():
            fail(self.label + ": a raised failure succeeded")
        if result^._take_err().errors.first() != CODE_BASE + self.id:
            fail(self.label + ": an attempt caught another failure")
        self.ledger[].bump(HANDLED + self.id)
        return 0


@fieldwise_init
struct Forget(OnceUnary):
    """Drop a started fiber's handle unjoined, then cede so it may run: its failure goes to the reporter.

    Whether the fiber raises before its owner finishes and cancels it is
    timing; either way a raised failure is reported exactly once.
    """
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        _ = fiber^
        return IO[NoneType, Int].cede().map(Const(0))


@fieldwise_init
struct SumPair(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


def observe(var failure: EffectFailure[Int], ids: List[Int], ledger: ArcPointer[Words], label: String):
    """A failure that surfaced above its `attempt`: each error must be one raised below, counted as handled."""
    for code in failure^.into_errors().into_list():
        var id = code - CODE_BASE
        var known = False
        for candidate in ids:
            known = known or candidate == id
        if not known:
            fail(String(label, ": error ", code, " surfaced where no failure below raised it"))
        ledger[].bump(HANDLED + id)


@fieldwise_init
struct CheckRace(OnceUnary):
    """One winner, carrying its own side's value."""
    var left: Int
    var right: Int
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = Result[RaceResult[Int, Int], EffectFailure[Int]]
    comptime Out = Int

    def call_once(deinit self, var attempted: Result[RaceResult[Int, Int], EffectFailure[Int]]) -> Int:
        if attempted.is_err():
            observe(attempted^._take_err(), self.ids, self.ledger, self.label)
            return 1
        var result = attempted^._take_ok()
        if result.isa[Left[Int]]():
            self.ledger[].bump(LEFT_WINS)
            if result^.unwrap[Left[Int]]().value != self.left:
                fail(self.label + ": a race's left winner carries another value")
        else:
            self.ledger[].bump(RIGHT_WINS)
            if result^.unwrap[Right[Int]]().value != self.right:
                fail(self.label + ": a race's right winner carries another value")
        return 1


@fieldwise_init
struct JoinIt(OnceUnary):
    var expected: Int
    var stoppable: Bool
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(CheckJoined(self.expected, self.stoppable, self.ids^, self.ledger^, self.label))


@fieldwise_init
struct CheckJoined(OnceUnary):
    """The child's own value. Below a race or a cancellation the joiner is being canceled when its child fails, and only then."""
    var expected: Int
    var stoppable: Bool
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        if self.stoppable and outcome and outcome.value().is_err():
            observe(outcome.take()._take_err(), self.ids, self.ledger, self.label)
            return self.expected
        if not outcome or not outcome.value().is_ok():
            fail(self.label + ": a joined fiber did not succeed")
        if outcome.take()._take_ok() != self.expected:
            fail(self.label + ": a joined fiber produced another value")
        return self.expected


@fieldwise_init
struct CancelIt(OnceUnary):
    """Cancel a started fiber, after a cede when `wait` is set, then join it."""
    var expected: Int
    var wait: Bool
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var stop = fiber.cancel()
        var then = stop^.flat_map(JoinCanceled(fiber^, self.expected, self.ids^, self.ledger^, self.label))
        if self.wait:
            return IO[NoneType, Int].cede().flat_map(Then(then^))
        return then^


@fieldwise_init
struct Then(OnceUnary):
    var next: IO[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.next^


@fieldwise_init
struct JoinCanceled(OnceUnary):
    var fiber: Fiber[Int, Int]
    var expected: Int
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join().map(CheckCanceled(self.expected, self.ids^, self.ledger^, self.label))


@fieldwise_init
struct CheckCanceled(OnceUnary):
    """Canceled, or finished first with the fiber's own value."""
    var expected: Int
    var ids: List[Int]
    var ledger: ArcPointer[Words]
    var label: String
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        if outcome:
            if not outcome.value().is_ok():
                observe(outcome.take()._take_err(), self.ids, self.ledger, self.label)
                return 1
            if outcome.take()._take_ok() != self.expected:
                fail(self.label + ": a canceled fiber finished with another value")
        else:
            self.ledger[].bump(CANCELED)
        return 1


@fieldwise_init
struct Kid(Unary, Copyable):
    """`par_traverse`'s function: a child's index to its program."""
    var context: Context
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var node: Int) -> IO[Int, Int]:
        return build(self.context, node)


@fieldwise_init
struct CheckOrder(OnceUnary):
    var expected: List[Int]
    var label: String
    comptime Arg = List[Int]
    comptime Out = Int

    def call_once(deinit self, var values: List[Int]) -> Int:
        if len(values) != len(self.expected):
            fail(self.label + ": par_traverse lost a result")
        var total = 0
        for i in range(len(values)):
            if values[i] != self.expected[i]:
                fail(self.label + ": par_traverse broke source order")
            total += values[i]
        return total


def microseconds(value: Int) -> Duration:
    try:
        return Duration.nanoseconds(value * 1_000)
    except:
        abort("wstp_stress: a valid duration")


def build(context: Context, node: Int) -> IO[Int, Int]:
    ref plan = context.plan[]
    var kind = plan.kind[node]
    var value = plan.value[node]
    var ledger = context.shared[].ledger.copy()
    if kind == PURE:
        return IO[Int, Int].pure(value)
    if kind == CEDE:
        return IO[NoneType, Int].cede().map(Const(value))
    if kind == SLEEP:
        return IO[NoneType, Int].sleep(microseconds(value)).map(Const(value))
    if kind == BLOCK:
        return IO[Tracked, Int].blocking(MakeTracked(ledger^, value)).map(Unwrap(value, context.label))
    if kind == FOREIGN:
        return IO[Tracked, Int].async_(Post(context.shared[].mailbox.copy(), ledger^, value)).map(Unwrap(value, context.label))
    if kind == SPIN:
        return IO[Int, Int].delay(Spin(value))
    if kind == FAIL:
        return IO[Int, Int].defer(Raise(ledger.copy(), value)).attempt().map(Handle(ledger^, value, context.label))
    if kind == ORPHAN:
        var failing = IO[Int, Int].defer(Raise(ledger^, value))
        if value % 2 == 1:
            failing = IO[NoneType, Int].cede().flat_map(Then(failing^))
        return failing^.start().flat_map(Forget())
    if kind == BOTH:
        return build(context, plan.first[node]).both(build(context, plan.second[node])).map(SumPair())
    if kind == RACE:
        var left = plan.first[node]
        var right = plan.second[node]
        var ids = List[Int]()
        plan.fail_ids(node, ids)
        return build(context, left).race(build(context, right)).attempt().map(CheckRace(plan.expected(left), plan.expected(right), ids^, ledger^, context.label))
    if kind == JOIN:
        var child = plan.first[node]
        var ids = List[Int]()
        plan.fail_ids(child, ids)
        return build(context, child).start().flat_map(JoinIt(plan.expected(child), plan.stoppable[node], ids^, ledger^, context.label))
    if kind == CANCEL:
        var child = plan.first[node]
        var ids = List[Int]()
        plan.fail_ids(child, ids)
        return build(context, child).start().flat_map(CancelIt(plan.expected(child), value == 1, ids^, ledger^, context.label))
    var kids = plan.kids[node].copy()
    var expected = List[Int]()
    for kid in kids:
        expected.append(plan.expected(kid))
    return par_traverse(kids^, Kid(context.copy())).map(CheckOrder(expected^, context.label))


# ===--- Rounds ---=== #


def profile_config(pooled: Bool) -> IORuntimeConfig:
    var config = IORuntimeConfig()
    config.reporter = report
    if pooled:
        try:
            config.profile = Profile.work_stealing(WORKERS)
        except:
            abort("wstp_stress: a valid worker count")
    else:
        config.profile = Profile.current_thread()
    return config^


def settle(shared: ArcPointer[Shared], label: String):
    """Wait for the producers to finish every posted completion; a lost one hangs, which the timeout reports."""
    var ledger = shared[].ledger.copy()
    var started = Int(monotonic())
    while ledger[].get(FINISHED) != ledger[].get(POSTED):
        if Int(monotonic()) - started > 10_000_000_000:
            fail(label + ": a posted completion was never finished")
        sleep(0.0)


def account(plan: Plan, shared: ArcPointer[Shared], pipe: Pipe, label: String, mut totals: List[Int]):
    """Exactly-once checks for one run: payloads, raised against handled and reported failures."""
    var ledger = shared[].ledger.copy()
    if ledger[].get(MADE) != ledger[].get(DESTROYED):
        fail(String(label, ": payloads made ", ledger[].get(MADE), ", destroyed ", ledger[].get(DESTROYED)))
    var reported = List[Int](length=MAX_FAILURES, fill=0)
    for line in read_reports(pipe):
        var start = line.find(": ")
        if start < 0:
            fail(label + ": an unexpected report: " + line)
        var digits = String(line[byte=start + 2:])
        var space = digits.find(" ")
        if space >= 0:
            var head = String(digits[byte=:space])
            digits = head^
        var code: Int
        try:
            code = Int(digits)
        except:
            fail(label + ": an unreadable report: " + line)
            return
        var id = code - CODE_BASE
        if id < 0 or id >= plan.failures:
            fail(label + ": a report of an unknown failure: " + line)
            return
        reported[id] += 1
    for node in range(len(plan.kind)):
        var kind = plan.kind[node]
        if kind != FAIL and kind != ORPHAN:
            continue
        var id = plan.value[node]
        var raised = ledger[].get(RAISED + id)
        if raised > 1:
            fail(String(label, ": failure ", id, " was raised ", raised, " times"))
        if kind == ORPHAN:
            totals[0] += raised
            totals[2] += reported[id]
            if reported[id] != raised:
                fail(String(label, ": unjoined failure ", id, " raised ", raised, " times was reported ", reported[id], " times"))
            continue
        var handled = ledger[].get(HANDLED + id)
        totals[0] += raised
        totals[1] += handled
        totals[2] += reported[id]
        if not plan.stoppable[node] and reported[id] != 0:
            fail(String(label, ": handled failure ", id, " was reported"))
        if handled + reported[id] != raised:
            fail(String(label, ": failure ", id, " raised ", raised, " times was handled ", handled, " and reported ", reported[id], " times"))


def one_run(plan: ArcPointer[Plan], shared: ArcPointer[Shared], pipe: Pipe, pooled: Bool, label: String, mut totals: List[Int]):
    shared[].ledger[].reset(RAISED, WORDS)
    var context = Context(plan.copy(), shared.copy(), label)
    var outcome = run(build(context, 0), profile_config(pooled))
    if not outcome:
        fail(label + ": the round's root was canceled")
    if not outcome.value().is_ok():
        var failure = outcome.take()._take_err()
        var text = String(label, ": the round's root failed (canceled ", failure.canceled, "):")
        for error in failure^.into_errors().into_list():
            text += String(" ", error)
        fail(text)
    var value = outcome.take()._take_ok()
    if value != plan[].expected(0):
        fail(String(label, ": the round produced ", value, ", the plan ", plan[].expected(0)))
    settle(shared, label)
    account(plan[], shared, pipe, label, totals)


def main():
    var seed = 1
    var rounds = ROUNDS
    try:
        if len(argv()) > 1:
            seed = Int(String(argv()[1]))
        if len(argv()) > 2:
            rounds = Int(String(argv()[2]))
    except:
        abort("wstp_stress: usage: wstp_stress [seed [rounds]]")
    print("wstp_stress: seed", seed)
    var pipe: Pipe
    try:
        pipe = Pipe.open_self_pipe()
    except:
        abort("wstp_stress: pipe")
    if external_call["dup2", c_int](pipe.write_end.fd, c_int(REPORT_FD)) != c_int(REPORT_FD):
        abort("wstp_stress: dup2")
    var shared = ArcPointer(Shared())
    var producers = List[OSThread[Producer]]()
    for i in range(PRODUCERS):
        try:
            producers.append(OSThread[Producer](ArcPointer(Producer(shared, UInt64(seed) * 7919 + UInt64(i) * 104729)), produce))
        except:
            abort("wstp_stress: could not start a producer")
    var random = Random(UInt64(seed))
    var nodes = 0
    # Failures raised, handled and reported, across every run.
    var totals = List[Int](length=3, fill=0)
    for round in range(rounds):
        var drawn = Plan()
        _ = draw(drawn, random, 0, False)
        nodes += len(drawn.kind)
        var plan = ArcPointer(drawn^)
        one_run(plan, shared, pipe, True, String("seed ", seed, " round ", round, " on the pool"), totals)
        one_run(plan, shared, pipe, False, String("seed ", seed, " round ", round, " on the current thread"), totals)
    shared[].ledger[].at(STOP).store[ordering=Ordering.RELEASE](1)
    producers.clear()
    _ = external_call["close", c_int](c_int(REPORT_FD))
    if nodes == 0:
        fail("no plan was drawn")
    # Timing-dependent totals go to stderr, so the reviewed stdout stays fixed.
    var ledger = shared[].ledger.copy()
    print(String("wstp_stress: ", nodes, " nodes per profile; payloads ", ledger[].get(MADE), " made and ", ledger[].get(DESTROYED),
        " destroyed; foreign completions ", ledger[].get(FINISHED), "; failures raised ", totals[0], ", handled ", totals[1],
        ", reported ", totals[2], "; race winners ", ledger[].get(LEFT_WINS), " left and ", ledger[].get(RIGHT_WINS),
        " right; canceled fibers ", ledger[].get(CANCELED)), file=stderr)
    print("wstp_stress: every round kept its value, its races' winners and its payloads and failures exactly once, on both profiles")
