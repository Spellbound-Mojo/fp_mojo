"""Cancellation across an `eval_on` region, on every kind of target.

- **Caller to region.** Canceling the caller while its region waits cancels
  the region: the region's finalizer has run, once, by the time
  `fiber.cancel()` returns, and the joined outcome is canceled.
- **Region to caller.** A region that cancels itself cancels its caller,
  whose own finalizer around the region runs once.
- **Masks.** Under `uncancelable`, a cancellation waits for the region to run
  to its end, and the region's finalizer does not run; with the region
  restored through the poll, the cancellation reaches it.
- **Timeouts.** A timeout around a region that never ends cancels it, runs its
  finalizer once, and fails with the timeout's error.
- **Repeated.** 100 cancellations in a row, each finalizing once.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk, OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Deferred, Duration, BlockingPool, ExecutionContext, IORuntimeConfig, Poll, Profile, Runtime, run


def check(condition: Bool, message: String):
    if not condition:
        abort(String("eval_on_cancel: ", message))


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def millis(count: Int) -> Duration:
    try:
        return Duration.milliseconds(count)
    except:
        abort("eval_on_cancel: a valid duration")


comptime Counter = ArcPointer[Atomic[Int]]


@fieldwise_init
struct Bump(OnceThunk):
    """Count one run of a finalizer or step."""
    var counter: Counter
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        _ = self.counter[].fetch_add(1)
        return None


def bump(counter: Counter) -> IO[NoneType, Int]:
    return IO[NoneType, Int].delay(Bump(counter.copy()))


struct Forever(OnceUnary, Defaultable):
    """After reporting that it runs, wait until canceled."""
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var completed: Bool) -> IO[Int, Int]:
        return IO[Int, Int].never()


def blocked(running: Deferred[Int], finalized: Counter) -> IO[Int, Int]:
    """A region that reports it runs, then waits until canceled; its finalizer counts."""
    return running.complete[Int](1).flat_map(Forever()).on_cancel(bump(finalized))


@fieldwise_init
struct Finish(OnceUnary):
    """After a pause, count the region's end and produce 7."""
    var finished: Counter
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return bump(self.finished).map(Seven())


struct Seven(OnceUnary, Defaultable):
    comptime Arg = NoneType
    comptime Out = Int

    def __init__(out self):
        pass

    def call_once(deinit self, var unit: NoneType) -> Int:
        return 7


@fieldwise_init
struct Pause(OnceUnary):
    var finished: Counter
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var completed: Bool) -> IO[Int, Int]:
        return IO[NoneType, Int].sleep(millis(30)).flat_map(Finish(self.finished.copy()))


def slow(running: Deferred[Int], finished: Counter, finalized: Counter) -> IO[Int, Int]:
    """A region that reports it runs, pauses 30 ms, then counts its end."""
    return running.complete[Int](1).flat_map(Pause(finished.copy())).on_cancel(bump(finalized))


# ===--- Cancel the caller, then check at once ---=== #


struct JoinCanceled(OnceUnary):
    """After the cancel returned: the region was finalized once; join the canceled child."""
    var fiber: Optional[Fiber[Int, Int]]
    var finalized: Counter
    var expected: Int
    comptime Arg = NoneType
    comptime Out = IO[Bool, Int]

    def __init__(out self, var fiber: Fiber[Int, Int], finalized: Counter, expected: Int):
        self.fiber = Optional(fiber^)
        self.finalized = finalized.copy()
        self.expected = expected

    def call_once(deinit self, var unit: NoneType) -> IO[Bool, Int]:
        var seen = self.finalized[].load()
        check(seen == self.expected, String("the region's finalizer ran ", seen, " times when cancel returned, expected ", self.expected))
        return self.fiber.take().join().map(WasCanceled())


struct WasCanceled(OnceUnary, Defaultable):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Bool

    def __init__(out self):
        pass

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Bool:
        return not outcome


struct CancelIt(OnceUnary):
    var fiber: Optional[Fiber[Int, Int]]
    var finalized: Counter
    var expected: Int
    comptime Arg = Int
    comptime Out = IO[Bool, Int]

    def __init__(out self, var fiber: Fiber[Int, Int], finalized: Counter, expected: Int):
        self.fiber = Optional(fiber^)
        self.finalized = finalized.copy()
        self.expected = expected

    def call_once(deinit self, var started: Int) -> IO[Bool, Int]:
        var fiber = self.fiber.take()
        var stop = fiber.cancel()
        return stop^.flat_map(JoinCanceled(fiber^, self.finalized, self.expected))


@fieldwise_init
struct CancelWhenRunning(OnceUnary):
    """Once the region reports it runs, cancel the caller's child that waits for it."""
    var running: Deferred[Int]
    var finalized: Counter
    var expected: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Bool, Int]:
        return self.running.get[Int]().flat_map(CancelIt(fiber^, self.finalized, self.expected))


def cancel_caller(target: ExecutionContext, name: String):
    var finalized = Counter(Atomic[Int](0))
    for _ in range(100):
        var running = Deferred[Int]()
        var before = finalized[].load()
        var program = blocked(running, finalized).eval_on(target).start().flat_map(CancelWhenRunning(running.copy(), finalized.copy(), before + 1))
        check(value_of(run(program^)), name + ": the canceled caller's child joins canceled")
    check(finalized[].load() == 100, name + ": each canceled region finalized once")


# ===--- The region cancels itself ---=== #


def region_cancels(target: ExecutionContext, name: String):
    var outer = Counter(Atomic[Int](0))
    var inner = Counter(Atomic[Int](0))
    var region = IO[NoneType, Int].canceled().map(Seven()).on_cancel(bump(inner)).eval_on(target)
    var outcome = run(region^.on_cancel(bump(outer)))
    check(not outcome, name + ": a self-canceled region cancels its caller")
    check(inner[].load() == 1 and outer[].load() == 1, name + ": both finalizers ran once")


# ===--- Masks ---=== #


@fieldwise_init
struct Masked(OnceUnary):
    """An uncancelable region, or one restored through the poll."""
    var region: Optional[IO[Int, Int]]
    var restore: Bool
    comptime Arg = Poll[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var poll: Poll[Int]) -> IO[Int, Int]:
        var region = self.region.take()
        if self.restore:
            return region^.restore(poll)
        return region^


def masks(target: ExecutionContext, name: String):
    var finished = Counter(Atomic[Int](0))
    var finalized = Counter(Atomic[Int](0))
    var running = Deferred[Int]()
    var region = slow(running, finished, finalized).eval_on(target)
    var program = IO[Int, Int].uncancelable(Masked(Optional(region^), False)).start().flat_map(CancelWhenRunning(running.copy(), finalized.copy(), 0))
    var in_region = value_of(run(program^))
    check(finished[].load() == 1 and finalized[].load() == 0, name + ": the masked region ran to its end")
    # The same masked program without a region: the region changes nothing.
    var local_running = Deferred[Int]()
    var local_finished = Counter(Atomic[Int](0))
    var unused = Counter(Atomic[Int](0))
    var local = slow(local_running, local_finished, unused)
    program = IO[Int, Int].uncancelable(Masked(Optional(local^), False)).start().flat_map(CancelWhenRunning(local_running.copy(), unused.copy(), 0))
    check(value_of(run(program^)) == in_region and local_finished[].load() == 1, name + ": the masked caller's outcome is the same as without a region")

    var restored_running = Deferred[Int]()
    var unfinished = Counter(Atomic[Int](0))
    var restored = slow(restored_running, unfinished, finalized).eval_on(target)
    program = IO[Int, Int].uncancelable(Masked(Optional(restored^), True)).start().flat_map(CancelWhenRunning(restored_running.copy(), finalized.copy(), 1))
    check(value_of(run(program^)), name + ": a restored region is canceled")
    check(unfinished[].load() == 0 and finalized[].load() == 1, name + ": the restored region was canceled before its end")


# ===--- Timeouts ---=== #


def timeouts(target: ExecutionContext, name: String):
    var finalized = Counter(Atomic[Int](0))
    var running = Deferred[Int]()
    var outcome = run(blocked(running, finalized).eval_on(target).timeout(millis(20), 99))
    check(Bool(outcome) and outcome.value().is_err(), name + ": the timeout fails")
    check(outcome.take()._take_err().errors.first() == 99, name + ": with the timeout's error")
    check(finalized[].load() == 1, name + ": the timed-out region finalized once")


def every_part(target: ExecutionContext, name: String):
    cancel_caller(target, name)
    region_cancels(target, name)
    masks(target, name)
    timeouts(target, name)


def main():
    var pooled: Runtime
    var single: Runtime
    var blocking: BlockingPool
    try:
        var config = IORuntimeConfig()
        config.profile = Profile.work_stealing(2)
        pooled = Runtime(config)
        var current = IORuntimeConfig()
        current.profile = Profile.current_thread()
        single = Runtime(current)
    except:
        abort("eval_on_cancel: the runtimes start")
    try:
        blocking = BlockingPool(max_workers=2)
    except:
        abort("eval_on_cancel: the blocking pool's configuration")
    every_part(pooled, "work-stealing runtime")
    every_part(single, "current-thread runtime")
    every_part(blocking, "blocking pool")
    print("eval_on cancel: caller and region cancellation, finalizers once, masks and timeouts on every target")
