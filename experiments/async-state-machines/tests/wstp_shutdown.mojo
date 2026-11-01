"""A work-stealing Runtime's shutdown: cancel and drain, then join, leaving nothing running.

- **Joins.** A runtime starts its workers when it is created; dropping its
  last copy stops and joins them all, after programs that started, joined
  and abandoned fibers (abandoned ones are canceled and drained by their
  owners). Repeated over many runtimes, so a leaked thread accumulates.
- **Copies.** Dropping one copy keeps the workers; the last copy joins them.
- **The last copy on a worker.** A program submitted without a caller's
  copy (through the private `_submit_root`, as a later fire-and-forget call
  would) drops the runtime's last copy inside its own step, on a worker. The
  runtime cannot join that thread: it joins the others and detaches it, and
  the detached thread finishes the program, leaves its loop and destroys the
  pool on its own.

Thread counts come from /proc, which can still count a joined thread for a
moment after its join returns, so every check bounds the count from above and
waits for it to settle (as `blocking_pool` does), which keeps them
deterministic. `SHUTDOWN_SCALE` multiplies the rounds for soaks.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort, getenv
from std.time import monotonic, sleep
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Profile, Runtime
from fp.effects._async.pool import _submit_root

comptime WORKERS = 4


def check(condition: Bool, message: String):
    if not condition:
        abort(String("wstp_shutdown: ", message))


def scale() -> Int:
    var text = getenv("SHUTDOWN_SCALE")
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
    abort("wstp_shutdown: cannot read the thread count")


def wait_until_threads(expected: Int) -> Bool:
    """Wait until at most `expected` threads remain; a joined thread can linger in /proc."""
    var deadline = Int(monotonic()) + 5_000_000_000
    while Int(monotonic()) < deadline:
        if os_threads() <= expected:
            return True
        sleep(0.002)
    return False


def stealing() -> IORuntimeConfig:
    var config = IORuntimeConfig()
    try:
        config.profile = Profile.work_stealing(WORKERS)
    except:
        abort("a valid worker count")
    return config^


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


# ===------------------------------------------------------------------=== #
# Programs: joined fibers and abandoned ones that never finish
# ===------------------------------------------------------------------=== #


@fieldwise_init
struct Abandon(OnceUnary):
    """Drop a never-ending fiber's handle; its owner cancels and drains it."""
    var left: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return mixed(self.left)


@fieldwise_init
struct Joined(OnceUnary):
    var left: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        _ = value_of(outcome^)
        return IO[Int, Int].never().start().flat_map(Abandon(self.left))


@fieldwise_init
struct JoinIt(OnceUnary):
    var left: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().flat_map(Joined(self.left))


def mixed(count: Int) -> IO[Int, Int]:
    """`count` rounds of a joined fiber and an abandoned one that never ends."""
    if count == 0:
        return IO[Int, Int].pure(7)
    return IO[Int, Int].pure(count).start().flat_map(JoinIt(count - 1))


# ===------------------------------------------------------------------=== #
# Checks
# ===------------------------------------------------------------------=== #


def joins() raises:
    var base = os_threads()
    for round in range(10 * scale()):
        var runtime = Runtime(stealing())
        check(os_threads() >= base + WORKERS, "a runtime starts its workers when created")
        for _ in range(5):
            check(value_of(runtime.run(mixed(6))) == 7, "programs with abandoned fibers complete")
        check(len(runtime.fibers()) == 0, "nothing is left running after the programs")
        _ = runtime^
        check(wait_until_threads(base), String("round ", round, ": dropping the last copy joins every worker, threads ", os_threads(), " of ", base))


def copies() raises:
    var base = os_threads()
    var runtime = Runtime(stealing())
    var copy = runtime.copy()
    _ = runtime^
    sleep(0.01)
    check(os_threads() >= base + WORKERS, "dropping one copy keeps the workers")
    check(value_of(copy.run(mixed(3))) == 7, "the remaining copy runs programs")
    _ = copy^
    check(wait_until_threads(base), String("the last copy joins, threads ", os_threads(), " of ", base))


struct Holder(Movable):
    """The runtime's last copy, carried into a program step that drops it on a worker."""
    var runtime: Runtime
    var released: ArcPointer[Atomic[Int]]
    var dropped: ArcPointer[Atomic[Int]]

    def __init__(out self, var runtime: Runtime, released: ArcPointer[Atomic[Int]], dropped: ArcPointer[Atomic[Int]]):
        self.runtime = runtime^
        self.released = released.copy()
        self.dropped = dropped.copy()


@fieldwise_init
struct DropLast(OnceUnary):
    var holder: Holder
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        # Wait until the submitter dropped its copy, so this one is the last.
        var deadline = Int(monotonic()) + 5_000_000_000
        while self.holder.released[].load() == 0 and Int(monotonic()) < deadline:
            sleep(0.0002)
        var dropped = self.holder.dropped.copy()
        # The last copy goes here: the runtime shuts down from its own worker.
        _ = self.holder^
        dropped[].store(1)
        return IO[Int, Int].pure(value + 1)


def last_copy_on_worker() raises:
    var base = os_threads()
    var released = ArcPointer(Atomic[Int](0))
    var dropped = ArcPointer(Atomic[Int](0))
    var runtime = Runtime(stealing())
    var pool = runtime._core[].pool.value().copy()
    var holder = Holder(runtime.copy(), released, dropped)
    var handle = _submit_root(pool, IO[Int, Int].pure(41).flat_map(DropLast(holder^)), CancellationToken(), IORuntimeConfig())
    # The program's copy is now the only one, and nothing else holds the pool.
    _ = runtime^
    _ = pool^
    released[].store(1)
    handle.wait()
    var outcome = handle^.take()
    check(dropped[].load() == 1, "the program dropped the last copy")
    check(value_of(outcome^) == 42, "the program that dropped the runtime still completed")
    check(wait_until_threads(base), String("the detached worker exited on its own, threads ", os_threads(), " of ", base))


def main() raises:
    joins()
    copies()
    last_copy_on_worker()
    print("wstp_shutdown: dropping the last copy joins every worker after abandoned fibers drain; copies keep the runtime; a last copy dropped on a worker detaches it")
