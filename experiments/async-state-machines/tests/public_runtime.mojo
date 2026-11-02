"""The public Runtime and Profile: shared copies, many programs, fiber dumps, both profiles.

- **Profiles.** `Profile`'s constructors, accessors, output, equality and
  validation; `IORuntimeConfig()` defaults to the work-stealing profile
  (the current-thread profile under `-D FP_ASYNC_PROFILE=current_thread`).
- **Where programs run.** A current-thread runtime runs a program on the
  calling thread; a work-stealing runtime runs it on one of its workers.
- **Copies share one runtime.** A program run through one copy is listed by
  another copy's `fibers()`, and a copy keeps working after the original is
  dropped.
- **Many programs.** Hundreds of programs, each starting and joining fibers,
  run on one runtime of each profile, and from two threads at once.
- **Fiber dumps.** `fibers()` lists a running program's live fibers, with its
  root number, from another thread; it lists nothing once programs complete,
  and roots are numbered in submission order.
- **Per-call run.** The free `run` with `Profile.work_stealing` starts no
  thread for a program that starts no fiber.
- **Snapshots race completion.** A thread calls `fibers()` in a loop while a
  work-stealing runtime starts and completes thousands of fibers on its
  workers (the reader count in `fiber_slots.mojo`).

`RUNTIME_SCALE` multiplies the program and churn counts for soaks.
"""
from std.atomic import Atomic
from std.ffi import external_call
from std.memory import ArcPointer
from std.os import abort, getenv
from std.sys.info import num_logical_cores
from std.time import monotonic, sleep
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, FiberInfo, FiberStatus, Deferred, IORuntimeConfig, Profile, Runtime, run
from fp._internal.os import OSThread, process_thread_count
from fp.effects._async.profile import _AUTO, _PER_CORE, _PROFILE


def check(condition: Bool, message: String):
    if not condition:
        abort(String("public runtime: ", message))


def scale() -> Int:
    var text = getenv("RUNTIME_SCALE")
    if not text:
        return 1
    try:
        return max(1, Int(text))
    except:
        return 1


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def stealing(workers: Int) -> IORuntimeConfig:
    var config = IORuntimeConfig()
    try:
        config.profile = Profile.work_stealing(workers)
    except:
        abort("a valid worker count")
    return config^


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def thread_value(var outcome: Outcome[UInt64, Int]) -> UInt64:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


# ===------------------------------------------------------------------=== #
# Programs
# ===------------------------------------------------------------------=== #


@fieldwise_init
struct StartNext(OnceUnary):
    """Drop a started waiter's handle (it stays live) and start the next."""
    var left: Int
    var cell: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return waiters(self.left, self.cell)


def waiters(count: Int, cell: Deferred[Int]) -> IO[Int, Int]:
    """Start `count` fibers that wait for the cell, then wait for it too."""
    if count == 0:
        return cell.get[Int]()
    return cell.get[Int]().start().flat_map(StartNext(count - 1, cell.copy()))


@fieldwise_init
struct JoinThen(OnceUnary):
    var left: Int
    var total: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().flat_map(Again(self.left, self.total))


@fieldwise_init
struct Again(OnceUnary):
    var left: Int
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        return churn(self.left, self.total + value_of(outcome^))


def churn(count: Int, total: Int = 0) -> IO[Int, Int]:
    """Start a fiber and join it, `count` times; the sum of 1 to `count`."""
    if count == 0:
        return IO[Int, Int].pure(total)
    return IO[Int, Int].pure(count).start().flat_map(JoinThen(count - 1, total))


def expected_churn(count: Int) -> Int:
    return count * (count + 1) // 2


# ===------------------------------------------------------------------=== #
# Threads that call into a runtime
# ===------------------------------------------------------------------=== #


struct Caller(Movable):
    """A thread that runs `programs` churn programs, or one waiter program, on a runtime copy."""
    var runtime: Runtime
    var cell: Deferred[Int]
    var waiting: Int
    var programs: Int
    var result: Atomic[Int]

    def __init__(out self, runtime: Runtime, cell: Deferred[Int], waiting: Int, programs: Int):
        self.runtime = runtime.copy()
        self.cell = cell.copy()
        self.waiting = waiting
        self.programs = programs
        self.result = Atomic(0)


def caller_body(state: Pointer[Caller, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    if state[].programs == 0:
        state[].result.store(value_of(state[].runtime.run(waiters(state[].waiting, state[].cell))))
        return None
    var total = 0
    for _ in range(state[].programs):
        total += value_of(state[].runtime.run(churn(8)))
    state[].result.store(total)
    return None


struct Dumper(Movable):
    """A thread that snapshots a runtime until told to stop."""
    var runtime: Runtime
    var stop: Atomic[Int]
    var snapshots: Atomic[Int]
    var listed: Atomic[Int]

    def __init__(out self, runtime: Runtime):
        self.runtime = runtime.copy()
        self.stop = Atomic(0)
        self.snapshots = Atomic(0)
        self.listed = Atomic(0)


def dumper_body(state: Pointer[Dumper, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    while state[].stop.load() == 0:
        var fibers = state[].runtime.fibers()
        for info in fibers:
            check(info.root >= 1 and info.index >= 1, "a runtime snapshot names a root and a slot")
        _ = state[].listed.fetch_add(len(fibers))
        _ = state[].snapshots.fetch_add(1)
    return None


def wait_for_fibers(runtime: Runtime, count: Int) -> List[FiberInfo]:
    """Snapshot until `count` fibers are listed, all suspended."""
    var deadline = Int(monotonic()) + 5_000_000_000
    while Int(monotonic()) < deadline:
        var fibers = runtime.fibers()
        if len(fibers) == count:
            var parked = True
            for info in fibers:
                if info.status != FiberStatus.suspended():
                    parked = False
            if parked:
                return fibers^
        sleep(0.001)
    abort(String("public runtime: expected ", count, " suspended fibers, found ", len(runtime.fibers())))


def fire(cell: Deferred[Int]):
    _ = run(cell.complete[Int](1))


# ===------------------------------------------------------------------=== #
# Checks
# ===------------------------------------------------------------------=== #


def profiles() raises:
    var current = Profile.current_thread()
    check(not current.is_work_stealing() and current.workers() == 1, "the current-thread profile runs on one thread")
    check(String(current) == "current_thread", "the current-thread profile's name")
    var pool = Profile.work_stealing(3)
    check(pool.is_work_stealing() and pool.workers() == 3, "a work-stealing profile keeps its workers")
    check(String(pool) == "work_stealing(3)", String("a work-stealing profile's name: ", pool))
    check(pool == Profile.work_stealing(3) and pool != Profile.work_stealing(2) and pool != current, "profiles compare")
    check(Profile.work_stealing().workers() >= 1, "the default pool has a worker per logical processor")
    var rejected = 0
    for workers in [0, -1, 32769]:
        try:
            _ = Profile.work_stealing(workers)
        except:
            rejected += 1
    check(rejected == 3, "a worker count outside 1 to 32768 raises")
    check(Profile.work_stealing(32768).workers() == 32768, "the largest pool is accepted")
    # The default is the work-stealing profile with a worker per logical
    # processor, or the current-thread profile on one processor; the
    # qualification defines select either profile outright.
    if _PROFILE == "work_stealing":
        check(IORuntimeConfig().profile == Profile.work_stealing(), "the pool define selects the work-stealing pool")
    elif _PROFILE == "current_thread":
        check(IORuntimeConfig().profile == Profile.current_thread(), "the current-thread routes default to the current thread")
    elif num_logical_cores() == 1:
        check(IORuntimeConfig().profile == Profile.current_thread(), "one processor defaults to the current thread")
    else:
        check(IORuntimeConfig().profile == Profile.work_stealing(), "the default profile is the work-stealing pool")
    default_resolution()
    check(IORuntimeConfig().max_blocking_threads == 64, "64 blocking threads by default")
    check(IORuntimeConfig().blocking_idle_timeout.to_nanoseconds() == 60_000_000_000, "a 60 s idle timeout by default")


def default_resolution() raises:
    """The default's run-time choice, through its one resolution hook, at forced processor counts."""
    var automatic = Profile(_workers=_AUTO)
    var single = automatic._resolved(1)
    check(not single.is_work_stealing() and single.workers() == 1, "one processor resolves the default to the current thread")
    check(single == Profile.current_thread() and String(single) == "current_thread", "the one-processor default is the current-thread profile")
    var four = automatic._resolved(4)
    check(four.is_work_stealing() and four.workers() == 4 and four == Profile.work_stealing(4), "four processors resolve the default to a pool of four")
    check(String(four) == "work_stealing(4)", "the resolved default writes its pool")
    check(Profile(_workers=_PER_CORE)._resolved(1) == Profile.work_stealing(1), "the pool define keeps a pool on one processor")
    check(Profile.work_stealing(1)._resolved(1).is_work_stealing(), "an explicit pool always wins")
    check(not Profile.current_thread()._resolved(8).is_work_stealing(), "an explicit current thread always wins")
    # The free `run` follows the resolved choice: on one processor the default
    # runs its program on the calling thread.
    var config = IORuntimeConfig()
    config.profile = single^
    var here = thread_id()
    var outcome = run(IO[UInt64, Int].delay(thread_id), config)
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == here, "a resolved one-processor default runs on the calling thread")


def where_programs_run() raises:
    var here = thread_id()
    var settings = IORuntimeConfig()
    settings.profile = Profile.current_thread()
    var current = Runtime(settings)
    check(thread_value(current.run(IO[UInt64, Int].delay(thread_id))) == here, "a current-thread runtime runs on the caller")
    var pool = Runtime(stealing(2))
    var there = thread_value(pool.run(IO[UInt64, Int].delay(thread_id)))
    check(there != here and there != 0, "a work-stealing runtime runs on one of its workers")


def copies_share() raises:
    var original = Runtime(stealing(2))
    var copy = original.copy()
    var cell = Deferred[Int]()
    var caller = OSThread(ArcPointer(Caller(copy, cell, 3, 0)), caller_body)
    # The program runs through one copy and is listed through the other.
    var listed = wait_for_fibers(original, 3)
    for info in listed:
        check(info.owner == 0 and info.root == listed[0].root, "the waiters belong to one root")
    fire(cell)
    var state = caller^.join()
    check(state[].result.load() == 1, "the program through the copy completed")
    check(len(original.fibers()) == 0, "nothing is listed once the program completes")
    _ = original^
    check(value_of(copy.run(churn(10))) == expected_churn(10), "a copy keeps working after the original is dropped")


def many_programs(config: IORuntimeConfig) raises:
    var runtime = Runtime(config)
    var count = 200 * scale()
    for i in range(count):
        check(value_of(runtime.run(churn(i % 7))) == expected_churn(i % 7), "each program's fibers join")
    # Two threads run programs on the same runtime at once.
    var a = OSThread(ArcPointer(Caller(runtime, Deferred[Int](), 0, 50 * scale())), caller_body)
    var b = OSThread(ArcPointer(Caller(runtime, Deferred[Int](), 0, 50 * scale())), caller_body)
    var first = a^.join()
    var second = b^.join()
    var each = 50 * scale() * expected_churn(8)
    check(first[].result.load() == each and second[].result.load() == each, "programs from two threads complete")
    check(len(runtime.fibers()) == 0, "nothing is listed after every program completed")


def numbered_roots() raises:
    var runtime = Runtime(stealing(2))
    var first_cell = Deferred[Int]()
    var first = OSThread(ArcPointer(Caller(runtime, first_cell, 1, 0)), caller_body)
    var one = wait_for_fibers(runtime, 1)
    var second_cell = Deferred[Int]()
    var second = OSThread(ArcPointer(Caller(runtime, second_cell, 2, 0)), caller_body)
    var three = wait_for_fibers(runtime, 3)
    check(three[0].root == one[0].root and three[1].root == three[2].root and three[1].root > three[0].root, "roots are numbered in submission order and grouped")
    fire(first_cell)
    fire(second_cell)
    _ = first^.join()
    _ = second^.join()
    # The same on the current-thread profile, whose roots run on their callers.
    var settings = IORuntimeConfig()
    settings.profile = Profile.current_thread()
    var current = Runtime(settings)
    var cell = Deferred[Int]()
    var caller = OSThread(ArcPointer(Caller(current, cell, 2, 0)), caller_body)
    var listed = wait_for_fibers(current, 2)
    check(listed[0].root == listed[1].root and listed[0].root >= 1, "a current-thread runtime lists its roots too")
    fire(cell)
    _ = caller^.join()
    check(len(current.fibers()) == 0, "and nothing once they complete")


def per_call_starts_no_thread() raises:
    # A worker joined by an earlier check can still be counted for a moment
    # (on macOS more often than on Linux), so the count is bounded from above.
    var base = process_thread_count()
    var seen = value_of(run(IO[Int, Int].delay(process_thread_count), stealing(4)))
    check(seen <= base, String("a trivial per-call run starts no thread: ", seen, " of ", base))
    check(value_of(run(churn(20), stealing(4))) == expected_churn(20), "a per-call run with fibers completes")


def snapshots_race_completion() raises:
    var runtime = Runtime(stealing(4))
    var dumper = OSThread(ArcPointer(Dumper(runtime)), dumper_body)
    var rounds = 40 * scale()
    for _ in range(rounds):
        check(value_of(runtime.run(churn(100))) == expected_churn(100), "churn completes while snapshots run")
    dumper.state()[].stop.store(1)
    var state = dumper^.join()
    check(state[].snapshots.load() > 0, "the dumper took snapshots")
    check(len(runtime.fibers()) == 0, "nothing is left listed")


def main() raises:
    profiles()
    where_programs_run()
    copies_share()
    many_programs(IORuntimeConfig())
    many_programs(stealing(4))
    numbered_roots()
    per_call_starts_no_thread()
    snapshots_race_completion()
    print("public runtime: profiles, where programs run, shared copies, many programs from two threads on both profiles, numbered fiber dumps, a per-call run starts no thread, snapshots racing completion")
