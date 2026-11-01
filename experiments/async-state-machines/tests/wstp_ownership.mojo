"""Ownership across workers: draining, joins, races and Supervisor on the work-stealing pool.

Every part runs on a four-worker pool through the private entry point
(`_run_pooled`). Fibers spin on arithmetic between steps so that they run on
several workers at once; the checks are invariants that hold whichever worker
runs what, never which side of a race wins.

- **Draining.** `OWNERS` fibers each start `CHILDREN` children that cede in a
  loop forever, then finish. Each owner's completion cancels its children and
  waits for them. Every child that started is canceled, no finalizer runs
  twice, and none runs after its owner completed. A child canceled before it
  first runs never enters its program, so it runs no finalizer ("starting
  observes cancellation"); on this profile that depends on timing.
- **Joins.** A fiber joins children that finish on other workers, and reads
  their values intact.
- **Races.** `RACES` races of two spinning sides with random lengths: exactly
  one side wins each race, and every losing side that was still running is
  canceled once (its finalizer runs once), never both.
- **Failures reported once.** Unjoined fibers that fail, started plainly and
  under a `Supervisor` that awaits them on release, are each reported exactly
  once, with their own error, and joined failures never are. The root waits
  until every plain one has failed before it ends: its own drain would cancel
  one still running, which then completes canceled and is not a failure.

The reporter is a thin function, so it writes each line to a pipe kept at a
fixed descriptor, which the main thread reads back.
"""
from std.atomic import Atomic, Ordering
from std.ffi import c_int, external_call
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Left
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Supervisor, RaceResult
from fp.effects._async.pool import _run_pooled
from fp._internal.os import Pipe

comptime WORKERS = 4
comptime OWNERS = 6
comptime CHILDREN = 8
comptime JOINS = 24
comptime RACES = 200
comptime FAILURES = 12
comptime SUPERVISED = 12
comptime SPIN = 4_000
comptime REPORT_FD = 77
"""The descriptor the reporter writes to: the pipe's write end, duplicated there."""


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_ownership: ", message))


def report(line: String):
    """The pool calls this from any worker, at once from several; each line is one write."""
    var text = line + "\n"
    var bytes = text.as_bytes()
    if external_call["write", Int](c_int(REPORT_FD), bytes.unsafe_ptr(), len(bytes)) != len(bytes):
        abort("wstp_ownership: the report pipe is full")


def config() -> IORuntimeConfig:
    var settings = IORuntimeConfig()
    settings.reporter = report
    return settings^


struct Counts(Movable):
    """Atomic counters in their own allocation."""
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

    def bump(self, index: Int) -> Int:
        return self.words[unsafe_offset=index].fetch_add[ordering=Ordering.ACQUIRE_RELEASE](1) + 1

    def get(self, index: Int) -> Int:
        return self.words[unsafe_offset=index].load[ordering=Ordering.ACQUIRE]()


def spin(seed: Int, rounds: Int) -> Int:
    var x = UInt64(seed) * 0x9E3779B97F4A7C15 + 1
    for _ in range(rounds):
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
    return Int(x & 0xFF)


@fieldwise_init
struct Bump(OnceUnary):
    var counts: ArcPointer[Counts]
    var index: Int
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        _ = self.counts[].bump(self.index)
        return None


def bump(counts: ArcPointer[Counts], index: Int) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(None).map(Bump(counts.copy(), index))


@fieldwise_init
struct Work(OnceUnary):
    """Spin for `left` steps, ceding between them, then succeed with `value`."""
    var left: Int
    var value: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(self.value)
        _ = spin(self.value + self.left, SPIN)
        return IO[NoneType, Int].cede().flat_map(Self(self.left - 1, self.value))


def work(steps: Int, value: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Work(steps, value))


@fieldwise_init
struct Forever(OnceUnary):
    """Spin and cede until canceled."""
    var seed: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        _ = spin(self.seed, SPIN)
        return IO[NoneType, Int].cede().flat_map(Self(self.seed + 1))


def forever(seed: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Forever(seed))


# ===--- Starting and joining many fibers ---=== #


comptime Make = def(Int, ArcPointer[Counts]) thin -> IO[Int, Int]


@fieldwise_init
struct StartRest(OnceUnary):
    """Keep a started fiber, then start the next; `finish` decides what to do with them all."""
    var next: Int
    var count: Int
    var fibers: List[Fiber[Int, Int]]
    var make: Make
    var counts: ArcPointer[Counts]
    var keep: Bool
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[List[Fiber[Int, Int]], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[List[Fiber[Int, Int]], Int]:
        if self.keep:
            self.fibers.append(fiber^)
        else:
            _ = fiber^
        if self.next == self.count:
            return IO[List[Fiber[Int, Int]], Int].pure(self.fibers^)
        var make = self.make
        return make(self.next, self.counts).start().flat_map(Self(self.next + 1, self.count, self.fibers^, self.make, self.counts^, self.keep))


def start_many(count: Int, make: Make, counts: ArcPointer[Counts], keep: Bool) -> IO[List[Fiber[Int, Int]], Int]:
    return make(0, counts).start().flat_map(StartRest(1, count, List[Fiber[Int, Int]](), make, counts.copy(), keep))


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
        check(Bool(outcome) and outcome.value().is_ok(), "a joined fiber succeeds")
        return join_sum(self.rest^, self.total + outcome.take()._take_ok())


@fieldwise_init
struct JoinAll(OnceUnary):
    comptime Arg = List[Fiber[Int, Int]]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fibers: List[Fiber[Int, Int]]) -> IO[Int, Int]:
        return join_sum(fibers^, 0)


# ===--- Draining ---=== #

# Counts: 0 children canceled, 1 owners finished, 2 children started.


@fieldwise_init
struct Started(OnceUnary):
    var seed: Int
    var counts: ArcPointer[Counts]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        _ = self.counts[].bump(2)
        return forever(self.seed)


def child(index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Started(index, counts.copy())).on_cancel(bump(counts, 0))


@fieldwise_init
struct OwnerEnd(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = List[Fiber[Int, Int]]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fibers: List[Fiber[Int, Int]]) -> IO[Int, Int]:
        # Drop the handles and finish: the scope cancels and drains the children.
        _ = fibers^
        return work(3, 1).map(Finished(self.counts^))


@fieldwise_init
struct Finished(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        _ = self.counts[].bump(1)
        return value


def owner(index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    return start_many(CHILDREN, child, counts, True).flat_map(OwnerEnd(counts.copy()))


@fieldwise_init
struct CheckDrained(OnceUnary):
    """After every owner was joined: each one's children were drained already."""
    var counts: ArcPointer[Counts]
    var seen: ArcPointer[Counts]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var total: Int) -> Int:
        var canceled = self.counts[].get(0)
        var started = self.counts[].get(2)
        # A child canceled at its first checkpoint runs its finalizer without
        # reaching the step that counts it as started.
        check(canceled >= started, "every child that started was canceled")
        check(canceled <= OWNERS * CHILDREN, "no child finalizer ran twice")
        _ = self.seen[].bump(0)
        self.seen[].words[unsafe_offset=1].store(canceled)
        return total


def draining():
    var counts = ArcPointer(Counts(3))
    var seen = ArcPointer(Counts(2))
    var program = start_many(OWNERS, owner, counts, True).flat_map(JoinAll()).map(CheckDrained(counts.copy(), seen.copy()))
    var outcome = _run_pooled(program^, CancellationToken(), config(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the draining root succeeds")
    check(outcome.take()._take_ok() == OWNERS, "every owner completed")
    check(seen[].get(0) == 1, "the drain check ran")
    check(counts[].get(0) == seen[].get(1), "no child finalizer ran after its owner completed")
    check(counts[].get(1) == OWNERS, "every owner finished its own work")


# ===--- Joins ---=== #


def joined(index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    return work(2 + index % 5, index * 10)


def joins():
    var counts = ArcPointer(Counts(1))
    var program = start_many(JOINS, joined, counts, True).flat_map(JoinAll())
    var outcome = _run_pooled(program^, CancellationToken(), config(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the joining root succeeds")
    var expected = 0
    for index in range(JOINS):
        expected += index * 10
    check(outcome.take()._take_ok() == expected, "every joined value arrives intact")


# ===--- Races ---=== #

# Counts: 0 left canceled, 1 right canceled, 2 left won, 3 right won.


@fieldwise_init
struct Tally(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = RaceResult[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var result: RaceResult[Int, Int]) -> Int:
        _ = self.counts[].bump(2 if result.isa[Left[Int]]() else 3)
        return 1


@fieldwise_init
struct Race(OnceUnary):
    var left: Int
    var counts: ArcPointer[Counts]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(done)
        var a = 1 + spin(self.left, 64) % 4
        var b = 1 + spin(self.left * 7, 64) % 4
        var left = work(a, 1).on_cancel(bump(self.counts, 0))
        var right = work(b, 2).on_cancel(bump(self.counts, 1))
        return left^.race(right^).map(Tally(self.counts.copy())).map(Plus(done)).flat_map(Self(self.left - 1, self.counts^))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


def racer(index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Race(RACES // 4, counts.copy()))


def races():
    var counts = ArcPointer(Counts(4))
    # Four racing fibers, so races run on several workers at once.
    var program = start_many(4, racer, counts, True).flat_map(JoinAll())
    var outcome = _run_pooled(program^, CancellationToken(), config(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the racing root succeeds")
    var total = 4 * (RACES // 4)
    check(outcome.take()._take_ok() == total, "every race finished")
    var left_won = counts[].get(2)
    var right_won = counts[].get(3)
    check(left_won + right_won == total, "exactly one side won each race")
    # A loser is canceled at most once, and only a side that lost can be.
    check(counts[].get(0) <= right_won and counts[].get(1) <= left_won, "only losers are canceled, once")


# ===--- Failures reported once ---=== #


@fieldwise_init
struct Fail(OnceUnary):
    var code: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return IO[Int, Int].raise_error(self.code)


def failing(index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    # The finalizer runs after the failure, so the count says it happened.
    return work(1 + index % 3, 0).flat_map(Fail(1000 + index)).guarantee(bump(counts, 0))


@fieldwise_init
struct UntilFailed(OnceUnary):
    """Cede until `count` failing fibers have failed."""
    var count: Int
    var counts: ArcPointer[Counts]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.counts[].get(0) >= self.count:
            return IO[NoneType, Int].pure(None)
        return IO[NoneType, Int].cede().flat_map(Self(self.count, self.counts^))


@fieldwise_init
struct JoinFailure(OnceUnary):
    """Join a failing fiber: its failure reaches the joiner and is never reported."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Joined())


@fieldwise_init
struct Joined(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        check(Bool(outcome) and outcome.value().is_err(), "a joined failure reaches its joiner")
        return 0


@fieldwise_init
struct Supervise(OnceUnary):
    """Supervise failing fibers, dropping their handles; release awaits them."""
    var next: Int
    var counts: ArcPointer[Counts]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        return supervise_all(supervisor^, 0, self.counts)


def supervise_all(var supervisor: Supervisor[Int], index: Int, counts: ArcPointer[Counts]) -> IO[Int, Int]:
    if index == SUPERVISED:
        return IO[Int, Int].pure(0)
    var program = failing(FAILURES + index, counts)
    return supervisor.supervise(program^).flat_map(Next(supervisor^, index + 1, counts.copy()))


@fieldwise_init
struct Next(OnceUnary):
    var supervisor: Supervisor[Int]
    var index: Int
    var counts: ArcPointer[Counts]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        _ = fiber^
        return supervise_all(self.supervisor^, self.index, self.counts)


@fieldwise_init
struct ThenSupervised(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = List[Fiber[Int, Int]]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var dropped: List[Fiber[Int, Int]]) -> IO[Int, Int]:
        # Plain fibers whose handles were dropped as they started; once they
        # have all failed, a joined failure, then the supervised ones.
        return IO[NoneType, Int].pure(None).flat_map(UntilFailed(FAILURES, self.counts.copy())).flat_map(StartJoined(self.counts^))


@fieldwise_init
struct StartJoined(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return failing(99, self.counts).start().flat_map(JoinFailure()).flat_map(ThenScope(self.counts^))


@fieldwise_init
struct ThenScope(OnceUnary):
    var counts: ArcPointer[Counts]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return Supervisor[Int].scoped(Supervise(0, self.counts^), await_on_release=True)


def failures():
    var counts = ArcPointer(Counts(1))
    var program = start_many(FAILURES, failing, counts, False).flat_map(ThenSupervised(counts.copy()))
    var outcome = _run_pooled(program^, CancellationToken(), config(), WORKERS)
    check(Bool(outcome) and outcome.value().is_ok(), "the reporting root succeeds")


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


def main():
    var pipe: Pipe
    try:
        pipe = Pipe.open_self_pipe()
    except:
        abort("wstp_ownership: pipe")
    if external_call["dup2", c_int](pipe.write_end.fd, c_int(REPORT_FD)) != c_int(REPORT_FD):
        abort("wstp_ownership: dup2")
    draining()
    joins()
    races()
    failures()
    var lines = read_reports(pipe)
    _ = external_call["close", c_int](c_int(REPORT_FD))
    check(len(lines) == FAILURES + SUPERVISED, String("each unjoined failure is reported once, got ", len(lines)))
    for code in range(1000, 1000 + FAILURES + SUPERVISED):
        var seen = 0
        for line in lines:
            if String(code) in line:
                seen += 1
        check(seen == 1, String("failure ", code, " reported exactly once"))
    for line in lines:
        check(not ("1099" in line), "a joined failure is never reported")
    print("wstp_ownership: draining, joins, races and supervised failures hold across workers")
