"""The bounded-stack guarantee on both profiles: a million frames under 1 MiB stacks.

The same programs run on the current-thread profile, through a `Runtime` on
the calling thread, and on a four-worker work-stealing pool whose workers
are started with 1 MiB native stacks through the pool's private
`stack_bytes` (`OSThread`'s pthread attribute). Each program first checks
the stack of the thread running it: exactly 1 MiB on a pool worker (macOS
reports 12 KiB more); on the calling thread, whatever `ulimit -s` gave it,
which qualification's bounded run sets to 1 MiB (`qualify.py`).

Programs, each a million frames deep unless stated:

- a runtime-built left-associated `flat_map` chain, every continuation
  invoked once;
- right-nested deferred recursion, a million `defer` frames at once;
- a failure crossing a million pending binds to its recovery, each skipped
  continuation destroyed once;
- deep cleanup: a failure crossing a million nested finalizers, each run once;
- cancellation: a fiber parked under a million pending frames, canceled and
  joined, each frame destroyed once; and, on the pool, a root canceled from
  the main thread through its token while it parks under a million frames;
- disposal of an unopened million-step chain, built and dropped inside a
  running program, on the thread that runs it;
- the left chain inside a started fiber, which another worker may steal.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys.info import CompilationTarget
from std.time import sleep
from fp.callables import OnceThunk, OnceUnary
from fp.effects import CancellationToken, EffectFailure, IOContext, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Profile, Runtime
from fp.effects.async_runtime.protocols import Machine, Step, Wait
from fp.effects._async.pool import _Pool, _submit_root
from fp._internal.os import current_thread_stack_bytes

comptime DEPTH = 1_000_000
comptime STACK = 1 << 20
comptime _REPORTED_EXTRA = 12 << 10 if CompilationTarget.is_macos() else 0
comptime WORKERS = 4


def check(condition: Bool, message: String):
    if not condition:
        abort(String("stack_profiles: ", message))


comptime INVOKED = 0
comptime DROPPED = 1
comptime CLEANED = 2
comptime PARKED = 3
comptime STACK_READ = 4
comptime WORDS = 5


struct Counters(Movable):
    """Counts shared with the workers, in their own allocation, used through immutable `self`."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]
    var pooled: Bool

    def __init__(out self, pooled: Bool):
        self.pooled = pooled
        self.words = unsafe_alloc[Atomic[Int]](WORDS)
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        for i in range(WORDS):
            self.words.unsafe_offset(i).unsafe_deinit_pointee()
        self.words.unsafe_free()

    def bump(self, index: Int, amount: Int = 1):
        _ = self.words[unsafe_offset=index].fetch_add[ordering=Ordering.RELEASE](amount)

    def get(self, index: Int) -> Int:
        return self.words[unsafe_offset=index].load[ordering=Ordering.ACQUIRE]()

    def set(self, index: Int, value: Int):
        self.words[unsafe_offset=index].store[ordering=Ordering.RELEASE](value)

    def reset(self):
        """Between programs, while no worker touches the counters."""
        for i in range(WORDS):
            self.set(i, 0)


comptime Shared = ArcPointer[Counters]


@fieldwise_init
struct AddOne(OnceUnary):
    """A continuation counting its invocations and its unopened drops.

    `call_once` consumes it without running `__deinit__`, so only a dropped,
    never-invoked continuation counts as dropped.
    """
    var counters: Shared
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def __deinit__(deinit self):
        self.counters[].bump(DROPPED)

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.counters[].bump(INVOKED)
        return IO[Int, Int].pure(value + 1)


@fieldwise_init
struct Increment(OnceUnary):
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value + 1


def counted(n: Int) -> IO[Int, Int]:
    """Right-nested recursion: each level maps over the next, so frames grow to n."""
    if n == 0:
        return IO[Int, Int].pure(0)
    return IO[Int, Int].defer(Counted(n)).map(Increment())


@fieldwise_init
struct Counted(OnceThunk):
    var n: Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call_once(deinit self) -> IO[Int, Int]:
        return counted(self.n - 1)


@fieldwise_init
struct Recover(OnceUnary):
    comptime Arg = EffectFailure[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var failure: EffectFailure[Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(-failure^.into_errors().into_list()[0])


@fieldwise_init
struct Forever(Machine):
    """Parks until canceled; counts its first poll so the canceler knows the frames are pending."""
    var counters: Shared
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        self.counters[].bump(PARKED)
        return .pending(Wait.never())


@fieldwise_init
struct Clean(OnceThunk):
    var counters: Shared
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        self.counters[].bump(CLEANED)
        return None


@fieldwise_init
struct CheckStack(OnceThunk):
    """Record the native stack of the thread running the program."""
    var counters: Shared
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        var bytes = current_thread_stack_bytes()
        self.counters[].set(STACK_READ, bytes)
        if self.counters[].pooled:
            # glibc reports the requested size; macOS reports 12 KiB more for
            # any requested size (measured at 1 MiB and 8 MiB).
            check(bytes == STACK + _REPORTED_EXTRA, String("a pool worker runs on a ", bytes, "-byte stack, not 1 MiB"))
        return 0


def left_chain(var source: IO[Int, Int], counters: Shared, count: Int = DEPTH) -> IO[Int, Int]:
    # One stable type at every depth: the loop instantiates no new type.
    var io = source^
    for _ in range(count):
        io = io^.flat_map(AddOne(counters.copy()))
    return io^


def on_checked_stack(var program: IO[Int, Int], counters: Shared) -> IO[Int, Int]:
    return IO[Int, Int].delay(CheckStack(counters.copy())).flat_map(Then(program^))


@fieldwise_init
struct Then(OnceUnary):
    var next: IO[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return self.next^


@fieldwise_init
struct BuildAndDrop(OnceThunk):
    """Build a million-step chain on the running thread and drop it unopened there."""
    var counters: Shared
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        var chain = left_chain(IO[Int, Int].pure(0), self.counters)
        _ = chain^
        return self.counters[].get(DROPPED)


@fieldwise_init
struct CancelDeep(OnceUnary):
    """Cede until the deep fiber parked, then cancel and join it."""
    var counters: Shared
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return IO[NoneType, Int].cede().flat_map(WaitParked(self.counters^, fiber^))


@fieldwise_init
struct WaitParked(OnceUnary):
    var counters: Shared
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.counters[].get(PARKED) == 0:
            return IO[NoneType, Int].cede().flat_map(WaitParked(self.counters^, self.fiber^))
        var stop = self.fiber.cancel()
        return stop^.flat_map(JoinCanceled(self.fiber^))


@fieldwise_init
struct JoinCanceled(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join().map(CanceledToValue())


@fieldwise_init
struct CanceledToValue(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        check(not outcome, "a fiber parked under a million frames was canceled")
        return 7


@fieldwise_init
struct JoinValue(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Joined())


@fieldwise_init
struct Joined(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        check(Bool(outcome) and outcome.value().is_ok(), "a deep fiber succeeded")
        return outcome.take()._take_ok()


# ===--- Hosts ---=== #


struct Host(Movable):
    """Runs a root on the current thread through a `Runtime`, or on the 1 MiB-stack pool."""
    var runtime: Optional[Runtime]
    var pool: Optional[ArcPointer[_Pool]]

    def __init__(out self, pooled: Bool) raises:
        self.runtime = None
        self.pool = None
        if pooled:
            var pool = ArcPointer(_Pool(WORKERS, 0, stack_bytes=STACK))
            pool[].start_all(Int(Pointer(to=pool[])))
            self.pool = Optional(pool^)
        else:
            var config = IORuntimeConfig()
            config.profile = Profile.current_thread()
            self.runtime = Optional(Runtime(config))

    def __deinit__(deinit self):
        if self.pool:
            self.pool.value()[].shutdown()

    def run(self, var program: IO[Int, Int], token: CancellationToken) raises -> Outcome[Int, Int]:
        if self.runtime:
            return self.runtime.value().run(program^, token)
        # Runtime.run's work-stealing path, on a pool built with 1 MiB stacks.
        var handle = _submit_root(self.pool.value(), program^, token, IORuntimeConfig())
        handle.wait()
        return handle^.take()

    def run(self, var program: IO[Int, Int]) raises -> Outcome[Int, Int]:
        return self.run(program^, CancellationToken())


def value_of(var outcome: Outcome[Int, Int], what: String) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), what + " succeeded")
    return outcome.take()._take_ok()


def scenarios(pooled: Bool) raises:
    var label = String("pool: ") if pooled else String("current thread: ")
    var host = Host(pooled)
    var counters = ArcPointer(Counters(pooled))

    # A runtime-built left-associated chain.
    check(value_of(host.run(on_checked_stack(left_chain(IO[Int, Int].pure(0), counters), counters)), label + "a left chain") == DEPTH, label + "a million binds")
    check(counters[].get(INVOKED) == DEPTH and counters[].get(DROPPED) == 0, label + "every continuation invoked once")
    check(counters[].get(STACK_READ) > 0, label + "the stack was read")

    # Right-nested deferred recursion: a million frames pending at once.
    check(value_of(host.run(on_checked_stack(counted(DEPTH), counters)), label + "deferred recursion") == DEPTH, label + "a million nested defer levels")

    # A failure crossing a million pending binds to its recovery.
    counters[].reset()
    var failing = left_chain(IO[Int, Int].raise_error(9), counters).handle_error_with(Recover())
    check(value_of(host.run(on_checked_stack(failing^, counters)), label + "recovery") == -9, label + "a failure crosses a million frames to recovery")
    check(counters[].get(DROPPED) == DEPTH and counters[].get(INVOKED) == 0, label + "every skipped continuation destroyed once")

    # Deep cleanup: a failure crossing a million nested finalizers.
    counters[].reset()
    var cleanup = IO[Int, Int].raise_error(3)
    for _ in range(DEPTH):
        cleanup = cleanup^.guarantee(IO[NoneType, Int].delay(Clean(counters.copy())))
    var cleaned = host.run(on_checked_stack(cleanup^, counters))
    check(Bool(cleaned) and cleaned.value().is_err(), label + "the failure survives its cleanup")
    check(cleaned.take()._take_err().into_errors().into_list()[0] == 3, label + "the body's failure, after a million finalizers")
    check(counters[].get(CLEANED) == DEPTH, label + "every finalizer ran once")

    # Cancellation of a fiber parked under a million frames.
    counters[].reset()
    var deep = left_chain(IO[Int, Int].lift(Forever(counters.copy())), counters)
    check(value_of(host.run(on_checked_stack(deep^.start().flat_map(CancelDeep(counters.copy())), counters)), label + "fiber cancellation") == 7, label + "the canceled fiber joined")
    check(counters[].get(DROPPED) == DEPTH and counters[].get(INVOKED) == 0, label + "cancellation unwinds every frame once")

    # Disposal of an unopened chain on the thread that runs the program.
    counters[].reset()
    check(value_of(host.run(on_checked_stack(IO[Int, Int].delay(BuildAndDrop(counters.copy())), counters)), label + "disposal") == DEPTH, label + "an unopened million-step chain destroyed iteratively")
    var unopened = left_chain(IO[Int, Int].pure(0), counters)
    _ = unopened^
    check(counters[].get(DROPPED) == 2 * DEPTH, label + "an unopened chain dropped by its owner")

    # The chain inside a started fiber.
    counters[].reset()
    var child = on_checked_stack(left_chain(IO[Int, Int].pure(0), counters), counters)
    check(value_of(host.run(child^.start().flat_map(JoinValue())), label + "a deep fiber") == DEPTH, label + "a million binds in a fiber")

    if pooled:
        # A root canceled from the main thread while it parks under a million frames.
        counters[].reset()
        var token = CancellationToken()
        var parked = left_chain(IO[Int, Int].lift(Forever(counters.copy())), counters)
        var handle = _submit_root(host.pool.value(), on_checked_stack(parked^, counters), token, IORuntimeConfig())
        while counters[].get(PARKED) == 0:
            sleep(0.0001)
        token.cancel()
        handle.wait()
        var outcome = handle^.take()
        check(not outcome, label + "the root was canceled")
        check(counters[].get(DROPPED) == DEPTH, label + "the canceled root unwound every frame once")
    _ = host^


def main() raises:
    scenarios(False)
    scenarios(True)
    print("stack profiles: a million binds, deferred levels, recovery, finalizers, cancellation and unopened disposal on the current thread and on 1 MiB pool workers")
