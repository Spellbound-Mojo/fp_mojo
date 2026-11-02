"""A long-lived `Runtime` keeps a flat footprint over many programs.

One `Runtime`, on the profile `IORuntimeConfig()` selects (`-D
FP_ASYNC_PROFILE`), runs rounds of separate programs, each through
`Runtime.run`:

- **Fibers.** Sequential start/join churn; a burst of live fibers joined
  together; a fiber parked forever, canceled and joined.
- **Timers.** A short sleep, and a timeout that wins over a program that
  never completes, which cancels the loser's timer.
- **`par_traverse`** over children that cede.
- **Blocking calls** returning a tracked payload (the blocking hand-off on the
  pool, the root's `BlockingPool` on the current thread).
- **Failures.** A root that fails, a failure recovered by `attempt`, a failing
  fiber whose join observes it, an unjoined failing fiber reported once, and
  a race whose loser is canceled.

Invariants checked every round: each program's value; every tracked payload
destroyed exactly once; one report per unjoined failure; and no live fiber
left on the runtime (`Runtime.fibers()`).

Storage. The resident set is sampled with `process_resident_bytes` after every
round. When the allocation counter of `probes/alloc_counter.c` is preloaded,
the live Mojo allocations (allocations minus frees) are sampled too; without
it they read -1 and are skipped. After a warm-up the samples may not grow:
the last window's peak may exceed the warm-up's peak by at most `RSS_SLACK`
bytes and `LIVE_SLACK` live allocations, so completed programs retain no
execution history.

Usage: `storage_soak [seconds]`. With no argument it runs `ROUNDS` rounds,
which qualification uses. With a duration it runs that long and writes one
line per second to standard error for the soak's report: `sample <seconds>
<rss bytes> <live Mojo allocations> <round> <live glibc allocations>
<threads> <anonymous rss kB>`. Standard output stays fixed.
"""
from std.atomic import Atomic, Ordering
from std.ffi import c_int, external_call
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv, stderr
from std.time import monotonic
from fp.algebra import par_traverse
from fp.callables import OnceThunk, OnceUnary, Unary
from fp.data import Right, Result
from fp.effects import EffectFailure, Outcome
from fp.effects.async_runtime import IO, Deferred, Fiber, Duration, IORuntimeConfig, RaceResult, Runtime
from fp._internal.os import Pipe, process_resident_bytes

comptime ROUNDS = 300
comptime WARMUP = 100
"""Rounds before the reference peak, in qualification; a timed soak uses its first tenth."""
comptime RSS_SLACK = 8 * 1024 * 1024
comptime LIVE_SLACK = 256
comptime CHURN = 64
comptime BURST = 32
comptime PAR = 16

# Ledger words.
comptime MADE = 0
comptime DESTROYED = 1
comptime WORDS = 2


def fail(message: String):
    abort(String("storage_soak: ", message))


struct Words(Movable):
    """Atomic counters in their own allocation, shared by every thread."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.words = unsafe_alloc[Atomic[Int]](WORDS)
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_deinit_pointee()
        self.words.unsafe_free()

    def bump(self, index: Int):
        _ = self.words[unsafe_offset=index].fetch_add[ordering=Ordering.RELAXED](1)

    def get(self, index: Int) -> Int:
        return self.words[unsafe_offset=index].load[ordering=Ordering.ACQUIRE]()


comptime REPORT_FD = 79
"""The reporter's descriptor: a self-pipe's write end, duplicated there."""


def report(line: String):
    """Count an unjoined failure's report with one byte; called from any thread."""
    var byte = UInt8(1)
    if external_call["write", Int](c_int(REPORT_FD), Pointer(to=byte), 1) != 1:
        abort("storage_soak: the report pipe is full")


def drain_reports(pipe: Pipe) -> Int:
    var total = 0
    var buffer = List[UInt8](length=256, fill=0)
    while True:
        var count = external_call["read", Int](pipe.read_end.fd, buffer.unsafe_ptr(), 256)
        if count <= 0:
            return total
        total += count


struct Tracked(Movable):
    """A payload counted when made and when destroyed."""
    var ledger: ArcPointer[Words]
    var value: Int

    def __init__(out self, ledger: ArcPointer[Words], value: Int):
        self.ledger = ledger.copy()
        self.value = value
        self.ledger[].bump(MADE)

    def __deinit__(deinit self):
        self.ledger[].bump(DESTROYED)


# ===--- Program pieces ---=== #


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct MakeTracked(OnceThunk):
    var ledger: ArcPointer[Words]
    var value: Int
    comptime Out = Tracked
    comptime Error = Never

    def call_once(deinit self) -> Tracked:
        return Tracked(self.ledger, self.value)


@fieldwise_init
struct Unwrap(OnceUnary):
    comptime Arg = Tracked
    comptime Out = Int

    def call_once(deinit self, var payload: Tracked) -> Int:
        return payload.value


@fieldwise_init
struct Fail(OnceThunk):
    var code: Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call_once(deinit self) -> IO[Int, Int]:
        return IO[Int, Int].raise_error(self.code)


def ceded(value: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].cede().map(Const(value))


@fieldwise_init
struct Churn(OnceUnary):
    """Start a fiber, join it, and continue until `limit` cycles ran."""
    var ledger: ArcPointer[Words]
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        var child = IO[Tracked, Int].delay(MakeTracked(self.ledger, count)).map(Unwrap())
        return child^.start().flat_map(JoinNext(self.ledger^, self.limit, count))


@fieldwise_init
struct JoinNext(OnceUnary):
    var ledger: ArcPointer[Words]
    var limit: Int
    var count: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().flat_map(CheckNext(self.ledger^, self.limit, self.count))


@fieldwise_init
struct CheckNext(OnceUnary):
    var ledger: ArcPointer[Words]
    var limit: Int
    var count: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        if not outcome or outcome.take()._take_ok() != self.count:
            fail("a churned fiber lost its value")
        return IO[Int, Int].pure(self.count + 1).flat_map(Churn(self.ledger^, self.limit))


@fieldwise_init
struct StartBurst(OnceUnary):
    """Start `remaining` more live fibers, then join them all, newest first."""
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.remaining == 0:
            return IO[Int, Int].pure(0).flat_map(JoinBurst(self.fibers^))
        return ceded(self.remaining).start().flat_map(KeepFiber(self.fibers^, self.remaining))


@fieldwise_init
struct KeepFiber(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        var unit: NoneType = None
        return IO[NoneType, Int].pure(unit).flat_map(StartBurst(self.fibers^, self.remaining - 1))


@fieldwise_init
struct JoinBurst(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if not self.fibers:
            return IO[Int, Int].pure(total)
        var fiber = self.fibers.pop()
        return fiber^.join().flat_map(AddJoined(self.fibers^, total))


@fieldwise_init
struct AddJoined(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        if not outcome:
            fail("a burst fiber was canceled")
        var value = outcome.take()._take_ok()
        return IO[Int, Int].pure(self.total + value).flat_map(JoinBurst(self.fibers^))


@fieldwise_init
struct CancelParked(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var stop = fiber.cancel()
        return stop^.flat_map(JoinCanceled(fiber^))


@fieldwise_init
struct JoinCanceled(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join().map(CheckCanceled())


@fieldwise_init
struct CheckCanceled(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        if outcome:
            fail("a fiber parked forever was not canceled")
        return 3


@fieldwise_init
struct CheckFailedJoin(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        if not outcome or not outcome.value().is_err():
            fail("a failing fiber's join did not observe its failure")
        var errors = outcome.take()._take_err().into_errors().into_list()
        if errors[0] != 42:
            fail("a failing fiber's join observed another failure")
        return 4


@fieldwise_init
struct JoinFailed(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(CheckFailedJoin())


@fieldwise_init
struct Forget(OnceUnary):
    """Drop an unjoined failing fiber, then wait until it failed; its failure is reported once.

    The child signals from its cleanup, after its failure, so the owner never
    cancels it before it ran.
    """
    var signal: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        _ = fiber^
        return self.signal.get[Int]()


@fieldwise_init
struct Discard(OnceUnary):
    comptime Arg = Bool
    comptime Out = NoneType

    def call_once(deinit self, var completed: Bool) -> NoneType:
        return None


def unjoined_failure() -> IO[Int, Int]:
    var signal = Deferred[Int]()
    var child = IO[Int, Int].defer(Fail(43)).guarantee(signal.complete[Int](5).map(Discard()))
    return child^.start().flat_map(Forget(signal^))


@fieldwise_init
struct Recovered(OnceUnary):
    comptime Arg = Result[Int, EffectFailure[Int]]
    comptime Out = Int

    def call_once(deinit self, var attempt: Result[Int, EffectFailure[Int]]) -> Int:
        if attempt.is_ok():
            fail("attempt missed a failure")
        return 6


@fieldwise_init
struct Kid(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var value: Int) -> IO[Int, Int]:
        return ceded(value)


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = List[Int]
    comptime Out = Int

    def call_once(deinit self, var values: List[Int]) -> Int:
        var total = 0
        for i in range(len(values)):
            if values[i] != i:
                fail("par_traverse broke source order")
            total += values[i]
        return total


@fieldwise_init
struct RightWon(OnceUnary):
    comptime Arg = RaceResult[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var result: RaceResult[Int, Int]) -> Int:
        if not result.isa[Right[Int]]():
            fail("a race's slow left side won")
        return result^.unwrap[Right[Int]]().value


# ===--- Rounds ---=== #


def micros(value: Int) -> Duration:
    try:
        return Duration.nanoseconds(value * 1_000)
    except:
        abort("storage_soak: a valid duration")


def expect_value(var outcome: Outcome[Int, Int], expected: Int, what: String):
    if not outcome or not outcome.value().is_ok():
        fail(what + " did not succeed")
    if outcome.take()._take_ok() != expected:
        fail(what + " produced another value")


def one_round(runtime: Runtime, ledger: ArcPointer[Words], pipe: Pipe, round: Int):
    var made = ledger[].get(MADE)
    expect_value(runtime.run(IO[Int, Int].pure(0).flat_map(Churn(ledger.copy(), CHURN))), CHURN, "churn")
    var unit: NoneType = None
    expect_value(runtime.run(IO[NoneType, Int].pure(unit).flat_map(StartBurst(List[Fiber[Int, Int]](), BURST))), BURST * (BURST + 1) // 2, "a burst")
    expect_value(runtime.run(IO[Int, Int].never().start().flat_map(CancelParked())), 3, "cancellation")
    expect_value(runtime.run(IO[NoneType, Int].sleep(micros(20)).map(Const(1))), 1, "a sleep")
    expect_value(runtime.run(IO[Int, Int].never().timeout_after(micros(50), IO[Int, Int].pure(2))), 2, "a timeout")
    var sources = List[Int]()
    for i in range(PAR):
        sources.append(i)
    expect_value(runtime.run(par_traverse(sources^, Kid()).map(Sum())), PAR * (PAR - 1) // 2, "par_traverse")
    expect_value(runtime.run(IO[Tracked, Int].blocking(MakeTracked(ledger.copy(), 7)).map(Unwrap())), 7, "a blocking call")
    var failed = runtime.run(IO[Int, Int].raise_error(40))
    if not failed or not failed.value().is_err():
        fail("a failing root did not fail")
    expect_value(runtime.run(IO[Int, Int].defer(Fail(42)).start().flat_map(JoinFailed())), 4, "a failing fiber's join")
    expect_value(runtime.run(unjoined_failure()), 5, "an unjoined failure")
    expect_value(runtime.run(IO[Int, Int].defer(Fail(44)).attempt().map(Recovered())), 6, "attempt")
    expect_value(runtime.run(IO[NoneType, Int].sleep(micros(1_000)).map(Const(8)).race(IO[Int, Int].pure(9)).map(RightWon())), 9, "a race")
    if ledger[].get(MADE) - made != CHURN + 1:
        fail(String("round ", round, ": tracked payloads made ", ledger[].get(MADE) - made))
    if ledger[].get(DESTROYED) != ledger[].get(MADE):
        fail(String("round ", round, ": a tracked payload was not destroyed exactly once"))
    var reports = drain_reports(pipe)
    if reports != 1:
        fail(String("round ", round, ": an unjoined failure was reported ", reports, " times"))
    if len(runtime.fibers()) != 0:
        fail(String("round ", round, ": a fiber outlived its program"))


# ===--- Storage samples ---=== #


def allocation_counts() -> Int:
    """The address of the preloaded counter's words, or 0 without it."""
    var name = List[UInt8]()
    for byte in "fp_alloc_counts".as_bytes():
        name.append(byte)
    name.append(0)
    return external_call["dlsym", Int](Int(0), name.unsafe_ptr())


def live_allocations(word: Int) -> Int:
    """Allocations minus frees from the preloaded counter: Mojo's heap at 0, glibc's at 3; -1 without it."""
    var address = allocation_counts()
    if address == 0:
        return -1
    var words = Pointer[Atomic[Int], MutUntrackedOrigin](unsafe_from_address=address)
    return words[unsafe_offset=word].load[ordering=Ordering.ACQUIRE]() - words[unsafe_offset=word + 1].load[ordering=Ordering.ACQUIRE]()


def status_field(name: String) -> Int:
    """A numeric field of /proc/self/status, such as Threads or RssAnon (in kB)."""
    try:
        with open("/proc/self/status", "r") as file:
            for line in file.read().split("\n"):
                if line.startswith(name + ":"):
                    var value = line[byte=name.byte_length() + 1:].strip()
                    return Int(value.split(" ")[0])
    except:
        pass
    return -1


struct Samples(Movable):
    var rss: List[Int]
    var live: List[Int]

    def __init__(out self):
        self.rss = List[Int]()
        self.live = List[Int]()

    def take(mut self, elapsed: Int, round: Int, timed: Bool):
        var rss = process_resident_bytes()
        var live = live_allocations(0)
        self.rss.append(rss)
        self.live.append(live)
        if timed:
            print("sample", elapsed // 1_000_000_000, rss, live, round, live_allocations(3), status_field("Threads"), status_field("RssAnon"), file=stderr)


def peak(values: List[Int], start: Int, end: Int) -> Int:
    var result = values[start]
    for i in range(start, end):
        result = max(result, values[i])
    return result


def check_flat(samples: Samples, warmup: Int):
    var count = len(samples.rss)
    if warmup < 1 or count < 2 * warmup:
        fail("too few samples to compare")
    var window = count - warmup
    var rss_growth = peak(samples.rss, window, count) - peak(samples.rss, 0, warmup)
    print("storage_soak: samples", count, "rss growth", rss_growth, "bytes", file=stderr)
    if rss_growth > RSS_SLACK:
        fail(String("the resident set grew by ", rss_growth, " bytes after warm-up"))
    if samples.live[0] >= 0:
        var live_growth = peak(samples.live, window, count) - peak(samples.live, 0, warmup)
        print("storage_soak: live allocation growth", live_growth, file=stderr)
        if live_growth > LIVE_SLACK:
            fail(String("live allocations grew by ", live_growth, " after warm-up"))


def main():
    var seconds = 0
    var arguments = argv()
    if len(arguments) > 1:
        try:
            seconds = Int(arguments[1])
        except:
            fail("the duration is a number of seconds")
    var ledger = ArcPointer(Words())
    var pipe: Pipe
    try:
        pipe = Pipe.open_self_pipe()
    except:
        fail("a report pipe")
        return
    if external_call["dup2", c_int](pipe.write_end.fd, c_int(REPORT_FD)) != c_int(REPORT_FD):
        fail("dup2")
    var config = IORuntimeConfig()
    config.reporter = report
    var samples = Samples()
    var started = Int(monotonic())
    var rounds = 0
    try:
        var runtime = Runtime(config)
        if seconds == 0:
            for round in range(ROUNDS):
                one_round(runtime, ledger, pipe, round)
                samples.take(Int(monotonic()) - started, round, False)
            rounds = ROUNDS
        else:
            var last = 0
            while Int(monotonic()) - started < seconds * 1_000_000_000:
                one_round(runtime, ledger, pipe, rounds)
                rounds += 1
                var elapsed = Int(monotonic()) - started
                if elapsed - last >= 1_000_000_000:
                    samples.take(elapsed, rounds, True)
                    last = elapsed
    except error:
        fail(String("a runtime could not start: ", error))
    check_flat(samples, WARMUP if seconds == 0 else max(1, len(samples.rss) // 10))
    _ = external_call["close", c_int](c_int(REPORT_FD))
    _ = pipe^
    print("storage_soak: rounds", rounds, "programs", rounds * 12, file=stderr)
    print("storage soak: a long-lived runtime ran fibers, timers, par_traverse, blocking calls and failures with a flat footprint")
