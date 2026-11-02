"""The target's lifetime around `eval_on` regions.

A region holds a copy of its target until its root has finished, so a target
whose other owners are all gone keeps running the region, then shuts down
from the region's own thread.

- **Dropped before the region runs.** The only copy of a runtime or pool is
  the one inside an unopened `eval_on` IO; the region still runs, and the
  target's threads exit once it ends.
- **Dropped while the region runs.** The caller's last copy goes while the
  region waits; the region runs to its end and then shuts the target down.
- **Listed while it runs.** A work-stealing runtime's `fibers()` lists a
  running region's root, and lists nothing once it ends.
- **Many short-lived targets.** 50 runtimes and pools, each used by one region
  and dropped, leave the process's thread count where it started.
"""
from std.os import abort
from std.time import sleep
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Deferred, BlockingPool, ExecutionContext, IORuntimeConfig, Profile, Runtime, run
from fp._internal.os import process_thread_count


def check(condition: Bool, message: String):
    if not condition:
        abort(String("eval_on_lifetime: ", message))


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def settle_threads(expected: Int, name: String):
    """Wait up to 5 s for detached threads to exit back to `expected`."""
    for _ in range(500):
        if process_thread_count() <= expected:
            return
        sleep(0.01)
    check(False, String(name, ": ", process_thread_count(), " threads left, expected ", expected))


def pooled_runtime() -> Runtime:
    try:
        var config = IORuntimeConfig()
        config.profile = Profile.work_stealing(2)
        return Runtime(config)
    except:
        abort("eval_on_lifetime: the runtime starts")


def single_runtime() -> Runtime:
    try:
        var config = IORuntimeConfig()
        config.profile = Profile.current_thread()
        return Runtime(config)
    except:
        abort("eval_on_lifetime: the runtime starts")


def blocking_pool() -> BlockingPool:
    try:
        return BlockingPool(max_workers=2)
    except:
        abort("eval_on_lifetime: the blocking pool's configuration")


def make_target(kind: Int) -> ExecutionContext:
    if kind == 0:
        return pooled_runtime()
    if kind == 1:
        return single_runtime()
    return blocking_pool()


def kind_name(kind: Int) -> String:
    if kind == 0:
        return "work-stealing runtime"
    if kind == 1:
        return "current-thread runtime"
    return "blocking pool"


# ===--- Dropped before the region runs ---=== #


def dropped_before(kind: Int):
    var name = kind_name(kind)
    var baseline = process_thread_count()
    var target = make_target(kind)
    var program = IO[Int, Int].pure(11).eval_on(target)
    _ = target^
    check(value_of(run(program^)) == 11, name + ": a region whose IO held the last copy runs")
    settle_threads(baseline, name + ": the target shut down after its region")


# ===--- Dropped while the region runs ---=== #


struct ReleaseThen(OnceUnary):
    """Once the region waits, drop the last outside copy and open its gate."""
    var gate: Deferred[Int]
    var target: Optional[ExecutionContext]
    comptime Arg = Int
    comptime Out = IO[Bool, Int]

    def __init__(out self, gate: Deferred[Int], var target: ExecutionContext):
        self.gate = gate.copy()
        self.target = Optional(target^)

    def call_once(deinit self, var started: Int) -> IO[Bool, Int]:
        _ = self.target.take()
        return self.gate.complete[Int](21)


@fieldwise_init
struct Report(OnceUnary):
    var running: Deferred[Int]
    var gate: Deferred[Int]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var completed: Bool) -> IO[Int, Int]:
        return self.gate.get[Int]()


struct JoinRegion(OnceUnary):
    var fiber: Optional[Fiber[Int, Int]]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def __init__(out self, var fiber: Fiber[Int, Int]):
        self.fiber = Optional(fiber^)

    def call_once(deinit self, var opened: Bool) -> IO[Int, Int]:
        return self.fiber.take().join_with(IO[Int, Int].pure(-1))


struct WaitThenRelease(OnceUnary):
    var running: Deferred[Int]
    var gate: Deferred[Int]
    var target: Optional[ExecutionContext]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def __init__(out self, running: Deferred[Int], gate: Deferred[Int], var target: ExecutionContext):
        self.running = running.copy()
        self.gate = gate.copy()
        self.target = Optional(target^)

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.running.get[Int]().flat_map(ReleaseThen(self.gate, self.target.take())).flat_map(JoinRegion(fiber^))


def dropped_during(kind: Int):
    var name = kind_name(kind)
    var baseline = process_thread_count()
    var running = Deferred[Int]()
    var gate = Deferred[Int]()
    var target = make_target(kind)
    var region = running.complete[Int](1).flat_map(Report(running.copy(), gate.copy())).eval_on(target)
    var program = region^.start().flat_map(WaitThenRelease(running, gate, target^))
    check(value_of(run(program^)) == 21, name + ": the region ran to its end after its target's last outside copy went")
    settle_threads(baseline, name + ": the target shut down after its region")


# ===--- Listed while it runs ---=== #


@fieldwise_init
struct Listed(OnceUnary):
    """While the region waits, read the runtime's dump, then open the gate."""
    var runtime: Runtime
    var gate: Deferred[Int]
    comptime Arg = Int
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var started: Int) -> IO[Bool, Int]:
        check(len(self.runtime.fibers()) >= 1, "fibers() lists a running region's root")
        return self.gate.complete[Int](3)


struct ListThenJoin(OnceUnary):
    var runtime: Runtime
    var running: Deferred[Int]
    var gate: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def __init__(out self, runtime: Runtime, running: Deferred[Int], gate: Deferred[Int]):
        self.runtime = runtime.copy()
        self.running = running.copy()
        self.gate = gate.copy()

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.running.get[Int]().flat_map(Listed(self.runtime^, self.gate^)).flat_map(JoinRegion(fiber^))


struct JoinChild(OnceUnary, Defaultable):
    """Join the region's child, which reported that it runs and waits on the gate."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var child: Fiber[Int, Int]) -> IO[Int, Int]:
        return child^.join_with(IO[Int, Int].pure(-1))


def listed():
    var runtime = pooled_runtime()
    var running = Deferred[Int]()
    var gate = Deferred[Int]()
    # The child reports that it runs, so it is listed, then waits on the gate.
    var child = running.complete[Int](1).flat_map(Report(running.copy(), gate.copy()))
    var region = child^.start().flat_map(JoinChild()).eval_on(runtime)
    check(value_of(run(region^.start().flat_map(ListThenJoin(runtime, running, gate)))) == 3, "the listed region completes")
    check(len(runtime.fibers()) == 0, "fibers() lists nothing once the region ended")


def many():
    var baseline = process_thread_count()
    for i in range(50):
        var target = make_target(i % 3)
        var program = IO[Int, Int].pure(i).eval_on(target)
        _ = target^
        check(value_of(run(program^)) == i, "a short-lived target's region")
    settle_threads(baseline, "50 short-lived targets")


def main():
    for kind in range(3):
        dropped_before(kind)
        dropped_during(kind)
    listed()
    many()
    print("eval_on lifetime: targets dropped before and during regions shut down after them, and runtimes list running regions")
