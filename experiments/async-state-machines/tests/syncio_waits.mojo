"""SyncIO's waits wake on a cancellation request made during the wait.

The token bridge (`CancellationToken._wake_on_cancel`) interrupts the poller a
synchronous wait parks in. An OS thread requests cancellation while the wait is
in progress:

- an inline `Interruption.sleep` and `await_readable` return False at once;
- `sleep_io` completes canceled at once, and under a mask sleeps its duration;
- the bridge fires its hook once per request and never after its
  subscription is dropped.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.callables import BorrowCallable, OnceUnary
from fp.algebra import flat_map
from fp.data import Result, Ok
from fp.effects import (IOContext, CancellationToken, Outcome, EffectFailure, SyncIO, Interruption,
    run_io, interruptible, uncancelable, canceled, sleep_io, unsafe_start)
from fp.effects._io_core import _IOSleep
from fp.effects import Fiber as Thread
from fp.effects import IO as SyncFamily
from fp.effects.protocols import ReaderAction
from fp.effects.async_runtime import Duration
from fp._internal.os import Pipe
from fp._internal.waking import _WakeHook

comptime S = SyncIO[Int]
comptime LONG_NS = 10_000_000_000
comptime PROMPT_NS = 2_000_000_000


def check(condition: Bool, message: String):
    if not condition:
        abort(String("syncio waits: ", message))


def spin(nanoseconds: Int):
    var end = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < end:
        pass


struct Canceler(ReaderAction):
    """Runs on an OS thread: once the function has started, wait, then request cancellation.

    Waiting for the start forces the request to arrive while the function runs,
    before or during its wait, so the function always observes it; a request
    before `run_io` enters the function would skip the function instead.
    """
    var token: CancellationToken
    var delay: Int
    var started: Optional[ArcPointer[Atomic[Int]]]
    comptime Family = SyncFamily[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def __init__(out self, token: CancellationToken, delay: Int, started: Optional[ArcPointer[Atomic[Int]]] = None):
        self.token = token.copy()
        self.delay = delay
        self.started = started.copy()

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        if self.started:
            var bound = Int(monotonic()) + PROMPT_NS
            while self.started.value()[].load() == 0:
                if Int(monotonic()) > bound:
                    abort("syncio waits: the function never started")
        spin(self.delay)
        self.token.cancel()
        var unit: NoneType = None
        return Optional(Result[NoneType, EffectFailure[Error]](Ok(unit)))


def cancel_later(token: CancellationToken, delay: Int, started: Optional[ArcPointer[Atomic[Int]]] = None) -> Thread[Canceler]:
    try:
        return unsafe_start(Canceler(token, delay, started))
    except:
        abort("syncio waits: unsafe_start failed")


def long() -> Duration:
    var duration = Duration()
    duration._nanoseconds = LONG_NS
    return duration^


@fieldwise_init
struct LongNap(BorrowCallable):
    """Sleep ten seconds through the handle; record what it reported."""
    var seen: ArcPointer[Atomic[Int]]
    var started: ArcPointer[Atomic[Int]]
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        self.started[].store(1)
        var slept = handle.sleep(long())
        self.seen[].store((1 if slept else 2) + (10 if handle.requested() else 20))
        return 0


@fieldwise_init
struct LongRead(BorrowCallable):
    """Wait ten seconds for a pipe nobody writes; record what it reported."""
    var fd: Int
    var seen: ArcPointer[Atomic[Int]]
    var started: ArcPointer[Atomic[Int]]
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        self.started[].store(1)
        var ready = True
        try:
            ready = handle.await_readable(RawFileDescriptor(Int32(self.fd)), Optional(long()))
        except:
            abort("syncio waits: poll failed")
        self.seen[].store((1 if ready else 2) + (10 if handle.requested() else 20))
        return 0


def interruptible_waits() raises:
    for delay in range(0, 5_000_001, 1_000_000):
        var token = CancellationToken()
        var seen = ArcPointer(Atomic[Int](0))
        var entered = ArcPointer(Atomic[Int](0))
        var thread = cancel_later(token, delay, Optional(entered.copy()))
        var started = Int(monotonic())
        _ = run_io(interruptible[S](LongNap(seen.copy(), entered.copy())), token)
        check(Int(monotonic()) - started < PROMPT_NS, "an inline sleep wakes on a request made during it")
        check(seen[].load() == 12, String("the sleep reports the request, saw ", seen[].load()))
        check(Bool(thread^.join()), "the canceler finished")
    var pipe = Pipe.open_self_pipe()
    for delay in range(0, 5_000_001, 1_000_000):
        var token = CancellationToken()
        var seen = ArcPointer(Atomic[Int](0))
        var entered = ArcPointer(Atomic[Int](0))
        var thread = cancel_later(token, delay, Optional(entered.copy()))
        var started = Int(monotonic())
        _ = run_io(interruptible[S](LongRead(Int(pipe.read_end.fd), seen.copy(), entered.copy())), token)
        check(Int(monotonic()) - started < PROMPT_NS, "an inline descriptor wait wakes on a request made during it")
        check(seen[].load() == 12, String("the descriptor wait reports the request, saw ", seen[].load()))
        check(Bool(thread^.join()), "the canceler finished")
    _ = pipe^
    print("interruptible: inline sleeps and descriptor waits return False at once on a request made during them")


@fieldwise_init
struct ThenSleep(OnceUnary):
    var seconds: Float64
    comptime Arg = NoneType
    comptime Out = _IOSleep[Int]

    def call_once(deinit self, var unit: NoneType) -> _IOSleep[Int]:
        try:
            return sleep_io[Int](self.seconds)
        except:
            abort("syncio waits: a valid sleep duration")


def sleeps() raises:
    for delay in range(0, 5_000_001, 1_000_000):
        var token = CancellationToken()
        var thread = cancel_later(token, delay)
        var started = Int(monotonic())
        var outcome = run_io(sleep_io[Int](10.0), token)
        check(Int(monotonic()) - started < PROMPT_NS, "sleep_io wakes on a request made during it")
        check(not outcome, "a sleep_io ended by a request completes canceled")
        check(Bool(thread^.join()), "the canceler finished")
    # Masked, the request, made inside the region before the sleep, waits for the sleep to end.
    var started = Int(monotonic())
    var masked = run_io(uncancelable(flat_map[SyncFamily[Int]](canceled[S](), ThenSleep(0.05))))
    check(Int(monotonic()) - started >= 50_000_000, "a masked sleep_io runs its whole duration")
    check(not masked, "the request is observed after the region")
    # Uncanceled, a sleep runs its duration.
    started = Int(monotonic())
    var plain = run_io(sleep_io[Int](0.02))
    check(Bool(plain) and Int(monotonic()) - started >= 20_000_000, "an uncanceled sleep_io runs its duration")
    print("sleep_io: a request during the sleep ends it at once; a mask defers it")


def count_wake(target: Int):
    _ = Pointer[Atomic[Int], MutUntrackedOrigin](unsafe_from_address=target)[].fetch_add(1)


def bridge():
    var fired = Atomic[Int](0)
    var hook = _WakeHook(Int(Pointer(to=fired)), count_wake)
    # Subscribed: a request fires the hook once.
    var token = CancellationToken()
    var subscription = token._wake_on_cancel(hook)
    token.cancel()
    token.cancel()
    check(fired.load() == 1, "one request fires the hook once")
    _ = subscription^
    # Already requested: subscribing fires at once.
    var late = token._wake_on_cancel(hook)
    check(fired.load() == 2, "subscribing after the request fires at once")
    _ = late^
    # Dropped: a later request wakes no one.
    var other = CancellationToken()
    var dropped = other._wake_on_cancel(hook)
    _ = dropped^
    other.cancel()
    check(fired.load() == 2, "the bridge wakes no one after unsubscribing")
    print("bridge: one hook call per request, at once when already requested, none after unsubscribing")


def main() raises:
    bridge()
    interruptible_waits()
    sleeps()
