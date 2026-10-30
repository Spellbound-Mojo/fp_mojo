"""Deterministic wake registration, timer invalidation and bounded driving."""
from foundation import at
from std.memory import ArcPointer
from fp._internal.waking import _Runtime
from fp._internal.cells import _lock_metadata
from fp.effects import CancellationToken, IOContext, ExitCase
from fp.callables import OnceUnary
from fp.effects._async.engine import IO, Fiber
from state_machine import Clock, Driver, Signal, Wait, Step, Sleep, Scope, ScopedMachine, CleanupMachine, pure
from foundation import check, success, Yielding, Waiter, both


def registry_orderings():
    var runtime = _Runtime()
    var parent = runtime.allocate(None, 0)
    runtime.begin(parent)
    var a = runtime.allocate(Optional(parent.copy()), 10)
    var b = runtime.allocate(Optional(parent.copy()), 20)
    runtime.begin(a)
    runtime.arm(a, False, None)
    runtime.begin(b)
    runtime.arm(b, False, None)
    runtime.arm(parent, False, None)
    check(not runtime.ready(parent), "consumed child readiness does not leave ancestors queued")
    var event = Signal()
    var old_revision = event.revision()
    event.notify()
    var before = event._subscribe(old_revision, runtime.waker(a))
    check(runtime.ready(a) and runtime.ready(parent), "notify before subscribe is retained")
    var after = event._subscribe(event.revision(), runtime.waker(b))
    event.notify()
    for _ in range(1000):
        event.notify()
    check(runtime.next_child(parent).value() == 10, "duplicate wakes preserve FIFO position")
    runtime.begin(a)
    runtime.arm(a, False, None)
    check(runtime.next_child(parent).value() == 20, "one queue entry per child")
    var stale_poll = runtime.waker(b)
    runtime.begin(b)
    runtime.arm(b, False, None)
    check(not stale_poll.wake(), "previous wait epoch rejected")
    _ = before^
    _ = after^
    var stale_task = runtime.waker(a)
    runtime.retire(a)
    var reused = runtime.allocate(Optional(parent.copy()), 30)
    check(reused.index == a.index and reused.generation != a.generation, "registry storage reused with a new generation")
    runtime.begin(reused)
    runtime.arm(reused, False, None)
    check(not stale_task.wake(), "retired task cannot wake replacement")
    runtime.retire(reused)
    runtime.retire(b)
    runtime.retire(parent)
    var guard = _lock_metadata(event._cell)
    check(guard.cell[].slot.value().active == 0 and len(guard.cell[].slot.value().entries) == 2, "subscriptions released and bounded")


def timer_lifecycle():
    var runtime = _Runtime()
    var a = runtime.allocate(None, 0)
    var b = runtime.allocate(None, 1)
    runtime.begin(a)
    runtime.begin(b)
    runtime.arm(a, False, Optional(at(20)))
    runtime.arm(b, False, Optional(at(10)))
    check(runtime.next_deadline().value() == at(10) and not runtime.fire_due(at(9)), "earliest timer and no early firing")
    runtime.begin(b)
    runtime.arm(b, False, Optional(at(30)))
    check(runtime.next_deadline().value() == at(20), "replaced deadline is discarded")
    check(runtime.fire_due(at(20)) and runtime.ready(a) and not runtime.ready(b), "only due timer wakes")
    runtime.retire(a)
    for i in range(1000):
        runtime.begin(b)
        runtime.arm(b, False, Optional(at(1000 + i)))
    var guard = _lock_metadata(runtime._cell)
    check(len(guard.cell[].slot.value().timers) <= 34 and guard.cell[].slot.value().live_timers == 1, "timer replacement does not grow retained tombstones")
    _ = guard^
    runtime.retire(b)
    check(not runtime.next_deadline() and not runtime.fire_due(at(10000)), "retired timers cannot fire")


def deterministic_driver():
    var clock = Clock.manual(100)
    var driver = Driver(both(Sleep[Int](10), Sleep[Int](20)), CancellationToken(), clock)
    var idle = driver.poll(20)
    check(not idle.completed and not idle.runnable and idle.deadline.value() == at(110), "nested sleeps use manual time")
    var none = driver.poll(0)
    check(none.polls == 0 and none.timers == 0, "zero budget performs no work")
    clock.advance_to(at(109))
    check(driver.poll(10).polls == 0, "idle poll does not scan or enter parked children")
    clock.advance_to(at(110))
    var next = driver.poll(10)
    check(not next.completed and next.deadline.value() == at(120) and next.timers == 1, "next live deadline exposed")
    clock.advance_to(at(120))
    check(driver.poll(10).completed, "second deadline finishes group")
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), "timed success")
    var trace = ArcPointer(List[Int]())
    var fair = Driver(both(Yielding(trace.copy(), 0, 4), Yielding(trace.copy(), 1, 4)))
    # A root poll ticks each ready fiber once, in FIFO order.
    var rounds = 0
    while not fair.poll(0).completed:
        var step = fair.poll(1)
        check(step.polls + step.timers <= 1, "one root poll per budget unit")
        rounds += 1
        check(rounds < 100, "fair children finish")
    check(len(trace[]) == 10, "each child polled until it finishes")
    for i in range(10):
        check(trace[][i] == i % 2, "ready children rotate FIFO")
    check(fair.poll(0).completed, "completed driver reports without polling")
    _ = fair^.finish()
    var state = ArcPointer(List[Int]([0, 0]))
    var raced = Driver(Waiter(Signal(), state.copy(), True))
    check(raced.poll(2).completed and state[][1] == 2, "wake during poll survives registration")
    _ = raced^.finish()


@fieldwise_init
struct Park(ScopedMachine):
    comptime Input = Int
    comptime Value = Int
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        return .pending(Wait.never())


@fieldwise_init
struct TimedCleanup(CleanupMachine):
    var timer: Sleep[Int]
    var calls: ArcPointer[Int]
    comptime Input = Int
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        check(context._masked and exit.is_canceled() and value == 42, "cleanup mask and resource")
        self.calls[] += 1
        return self.timer.poll(context)


def cancellation_and_cleanup():
    var clock = Clock.manual()
    var calls = ArcPointer(0)
    var token = CancellationToken()
    var driver = Driver(Scope(pure[Int](42), Park(), TimedCleanup(Sleep[Int](50), calls.copy())), token, clock)
    check(not driver.poll(10).runnable, "scope use parked")
    token.cancel()
    var cleanup = driver.poll(10)
    check(not cleanup.completed and not cleanup.runnable and cleanup.deadline.value() == at(50), "cancellation starts masked cleanup")
    token.cancel()
    check(driver.poll(10).polls == 0 and calls[] == 1, "repeated cancellation does not repoll cleanup")
    clock.advance_to(at(49))
    check(driver.poll(10).polls == 0, "cleanup timer does not fire early")
    var moved = driver^
    clock.advance_to(at(50))
    check(moved.poll(10).completed and calls[] == 2, "moved driver drains timed cleanup")
    check(not moved^.finish(), "cancellation preserved after cleanup")


@fieldwise_init
struct StartSleepers(OnceUnary):
    """Start one timer fiber per remaining index, then wait until canceled."""
    var next: Int
    var limit: Int
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[NoneType, Int]:
        if self.next == self.limit:
            return IO[NoneType, Int].never()
        return sleeper(self.next).start().flat_map(StartSleepers(self.next + 1, self.limit))


def sleeper(index: Int) -> IO[NoneType, Int]:
    return IO[NoneType, Int].lift(Sleep[Int](10 + index))


def parked_fibers():
    var clock = Clock.manual()
    var program = sleeper(0).start().flat_map(StartSleepers(1, 128))
    var driver = Driver(program^, CancellationToken(), clock)
    var parked = driver.poll(256)
    check(not parked.runnable and parked.deadline.value() == at(10), "all timer fibers parked")
    for _ in range(100):
        check(driver.poll(100).polls == 0, "idle fibers perform no polls")
    clock.advance_to(at(10))
    var one = driver.poll(2)
    check(one.timers == 1 and one.polls == 1 and one.deadline.value() == at(11), "one timer selects one fiber")
    driver.cancel()
    var done = driver.poll(1000)
    check(done.completed and not done.deadline, "cancellation removes remaining timer registrations")
    var runtime = driver.task.context._runtime.value().copy()
    check(not driver^.finish(), "owner cancellation")
    var guard = _lock_metadata(runtime._cell)
    check(guard.cell[].slot.value().active == 0 and guard.cell[].slot.value().live_timers == 0, "all registrations retired")


def main():
    registry_orderings()
    timer_lifecycle()
    deterministic_driver()
    cancellation_and_cleanup()
    parked_fibers()
    print("scheduler: deterministic wakes, FIFO budgets, stale generations, timer bounds, manual time, masked cleanup")
