"""The live-registration count under callbacks registered and dropped on OS threads.

Callbacks count themselves on the root scheduler's atomic counter when they
register and uncount themselves when they are dropped, wherever that happens.
Three threads register callbacks of their own and drop them, and also drop
callbacks the main thread registered, while the main thread samples the count
and `TestControl.is_deadlocked`. The count never leaves its bounds, the control
is not deadlocked while a registration lives, and it ends at exactly zero.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv, abort
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, Fiber
from fp.effects._io_core import _Budget
from fp.effects._async.callbacks import Completion, Callback, callback
from fp.effects._async.kernel import Machine, Step
from fp.effects.async_runtime import IO, TestControl
from wstp_support import check, WstpJob, WstpThread, wstp_start

comptime THREADS = 3


@fieldwise_init
struct Register(OnceUnary):
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var done: Completion[Int, Int]) -> NoneType:
        return None


@fieldwise_init
struct Withdrawn(Machine):
    comptime Value = NoneType
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        var unit: NoneType = None
        return Step[NoneType, Int].ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))


comptime Registration = Callback[Register, Withdrawn]


def registered(budget: ArcPointer[_Budget]) -> Registration:
    """A callback polled once, so it has registered and counted itself."""
    var context = IOContext[Int](CancellationToken(), False)
    context._budget = Optional(budget.copy())
    var registration = callback(Register(), Withdrawn())
    _ = registration.poll(context)
    return registration^


struct Dropper(WstpJob):
    var budget: ArcPointer[_Budget]
    var foreign: List[Registration]
    var own: Int
    var ready: ArcPointer[Atomic[Int]]
    var go: ArcPointer[Atomic[Int]]

    def __init__(out self, budget: ArcPointer[_Budget], var foreign: List[Registration], own: Int, ready: ArcPointer[Atomic[Int]], go: ArcPointer[Atomic[Int]]):
        self.budget = budget.copy()
        self.foreign = foreign^
        self.own = own
        self.ready = ready.copy()
        self.go = go.copy()

    def work(deinit self):
        _ = self.ready[].fetch_add(1)
        while self.go[].load[ordering=Ordering.ACQUIRE]() == 0:
            pass
        var mine = List[Registration]()
        for i in range(self.own):
            mine.append(registered(self.budget))
            if i % 4 == 3:
                _ = mine.pop()
                _ = self.foreign.pop() if self.foreign else registered(self.budget)
        # Everything left is dropped here, on this thread.


def round(per_thread: Int) raises:
    var control = TestControl(IO[Int, Int].never())
    control.tick()
    check(control.is_deadlocked(), "a program waiting on nothing is deadlocked")
    var budget = control._driver._driver.task._executor.budget.copy()
    var counter = budget[].registrations.copy()
    var ready = ArcPointer(Atomic(0))
    var go = ArcPointer(Atomic(0))
    var threads = List[Fiber[WstpThread[Dropper]]]()
    for _ in range(THREADS):
        var foreign = List[Registration]()
        for _ in range(per_thread):
            foreign.append(registered(budget))
        # A failed start aborts: the linear control cannot be abandoned by a raise.
        try:
            threads.append(wstp_start(Dropper(budget, foreign^, per_thread, ready, go)))
        except:
            abort("race registrations: a thread did not start")
    var total = THREADS * per_thread
    check(counter[].load() == total, "each registration counts once")
    check(not control.is_deadlocked(), "live registrations await external events")
    while ready[].load() < THREADS:
        pass
    go[].store[ordering=Ordering.RELEASE](1)
    # Each thread holds at most its foreign callbacks plus its own at once.
    var bound = 2 * total
    var sampled = 0
    while sampled < 10_000:
        var count = control._driver._driver.task._executor.scheduler[].registered()
        check(count >= 0 and count <= bound, "the count stays within its bounds")
        sampled += 1
    while threads:
        _ = threads.pop().join()
    check(counter[].load() == 0, "every dropped registration uncounted itself once")
    check(control.is_deadlocked(), "no registration remains")
    control.request_cancel()
    control.tick()
    _ = control^.results()


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    for _ in range(8):
        round(2_000 * scale)
    print("race registrations: callbacks registered and dropped on three threads; the count stays exact")
