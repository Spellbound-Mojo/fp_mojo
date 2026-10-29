"""Typed resumable work with no coroutine intrinsics or context-switch ABI."""
from std.memory import OwnedPointer
from std.time import sleep
from std.os import abort
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects._io_core import _settle
from fp.data import Result, Ok
from fp._internal.waking import _Event as Signal, _Runtime, _Ticket, _Subscription, _Waker, _Clock as Clock


@fieldwise_init
struct _Wake(Copyable):
    var signal: Optional[Signal]
    var revision: UInt64
    var deadline: Optional[Int]
    var token: Optional[CancellationToken]

    def ready(self, now: Int) -> Bool:
        return (Bool(self.signal) and self.signal.value().revision() != self.revision
            or Bool(self.deadline) and now >= self.deadline.value()
            or Bool(self.token) and self.token.value().requested())


struct Wait(Copyable):
    var signal: Optional[Signal]
    var revision: UInt64
    var deadline: Optional[Int]
    var interruptible: Bool
    var runnable: Bool
    var _wakes: List[_Wake]

    def __init__(out self):
        self.signal = None
        self.revision = 0
        self.deadline = None
        self.interruptible = True
        self.runnable = True
        self._wakes = List[_Wake]()

    @staticmethod
    def never() -> Self:
        var wait = Self()
        wait.runnable = False
        return wait^

    def include[E: Movable & Deinitable](mut self, other: Self, context: IOContext[E]):
        """Flatten owned descriptors, binding cancellation to its actual token."""
        self.runnable = self.runnable or other.runnable
        if other.signal or other.deadline:
            self._wakes.append(_Wake(other.signal.copy(), other.revision, other.deadline.copy(), None))
        if other.interruptible and not context._masked:
            self._wakes.append(_Wake(None, 0, None, Optional(context._token.copy())))
        for wake in other._wakes:
            self._wakes.append(wake.copy())

    @staticmethod
    def changed(signal: Signal, revision: UInt64) -> Self:
        var wait = Self.never()
        wait.signal = Optional(signal.copy())
        wait.revision = revision
        return wait^

    @staticmethod
    def until(deadline: Int) -> Self:
        var wait = Self.never()
        wait.deadline = Optional(deadline)
        return wait^

    def ready[E: Movable & Deinitable](self, now: Int, context: IOContext[E]) -> Bool:
        if self.interruptible and context.canceled():
            return True
        if self.signal and self.signal.value().revision() != self.revision:
            return True
        if self.deadline and now >= self.deadline.value():
            return True
        for wake in self._wakes:
            if wake.ready(now):
                return True
        return self.runnable


struct _Scheduled(Movable):
    var runtime: _Runtime
    var ticket: _Ticket
    var subscriptions: List[_Subscription]

    def __init__(out self, runtime: _Runtime, parent: Optional[_Ticket], tag: Int):
        self.runtime = runtime.copy()
        self.ticket = runtime.allocate(parent, tag)
        self.subscriptions = List[_Subscription]()

    def __deinit__(deinit self):
        self.subscriptions.clear()
        self.runtime.retire(self.ticket)

    def begin(mut self):
        self.subscriptions.clear()
        self.runtime.begin(self.ticket)

    def cancel_subscription(mut self, token: CancellationToken, target: _Waker):
        var revision = token._event.revision()
        self.subscriptions.append(token._event.subscribe(revision, target))
        if token.requested():
            _ = target.wake()

    def arm[E: Movable & Deinitable](mut self, wait: Wait, context: IOContext[E]):
        if wait.runnable:
            self.runtime.arm(self.ticket, True, None)
            return
        if not wait.signal and not len(wait._wakes) and (not wait.interruptible or context._masked):
            self.runtime.arm(self.ticket, False, wait.deadline)
            return
        var target = self.runtime.waker(self.ticket)
        var deadline = wait.deadline.copy()
        if wait.signal:
            self.subscriptions.append(wait.signal.value().subscribe(wait.revision, target))
        if wait.interruptible and not context._masked:
            self.cancel_subscription(context._token, target)
        for wake in wait._wakes:
            if wake.signal:
                self.subscriptions.append(wake.signal.value().subscribe(wake.revision, target))
            if wake.token:
                self.cancel_subscription(wake.token.value(), target)
            if wake.deadline and (not deadline or wake.deadline.value() < deadline.value()):
                deadline = wake.deadline.copy()
        self.runtime.arm(self.ticket, wait.runnable, deadline)


struct Step[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    # Outer absence means pending; inner absence is a completed cancellation.
    var completed: Optional[Outcome[Self.T, Self.E]]
    var wait: Wait
    var _protected_success: Bool

    @staticmethod
    def ready(var outcome: Outcome[Self.T, Self.E]) -> Self:
        return Self(Optional(outcome^), Wait())

    @staticmethod
    def pending(var wait: Wait) -> Self:
        return Self(None, wait^)

    def outcome(deinit self) -> Outcome[Self.T, Self.E]:
        return self.completed.take()

    def waiting(deinit self) -> Wait:
        return self.wait^

    def __init__(out self, var completed: Optional[Outcome[Self.T, Self.E]], var wait: Wait, protected_success: Bool = False):
        self.completed = completed^
        self.wait = wait^
        self._protected_success = protected_success


trait Machine(Movable, Deinitable):
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        ...


struct _Slot[P: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """Private running storage. Only a linear root may own entered slots."""
    # Native typed indirection bounds frame size for deeply nested bind types.
    var _program: Optional[OwnedPointer[Self.P]]
    var _result: Optional[Outcome[Self.T, Self.E]]
    var _wait: Wait
    var entered: Bool
    var polls: Int
    var _scheduled: Optional[_Scheduled]
    var _tag: Int
    var _protected_success: Bool

    def __init__(out self, var program: Self.P, tag: Int = 0):
        self._program = Optional(OwnedPointer(program^))
        self._result = None
        self._wait = Wait()
        self.entered = False
        self.polls = 0
        self._scheduled = None
        self._tag = tag
        self._protected_success = False

    def __deinit__(deinit self):
        if self.entered and not self.done():
            abort("entered execution slot abandoned before cleanup completed")

    def done(self) -> Bool:
        return not self._program

    def ready(self, now: Int, context: IOContext[Self.E]) -> Bool:
        if self._scheduled:
            return self._scheduled.value().runtime.ready(self._scheduled.value().ticket)
        return not self.done() and self._wait.ready(now, context)

    def prepare(mut self, context: IOContext[Self.E]):
        if not self.done() and not self._scheduled and context._runtime:
            self._scheduled = Optional(_Scheduled(context._runtime.value(), context._parent, self._tag))

    def poll_context(self, context: IOContext[Self.E]) -> IOContext[Self.E]:
        var nested = context.copy()
        if self._scheduled:
            nested._parent = Optional(self._scheduled.value().ticket.copy())
        return nested^

    def waiting(self) -> Wait:
        if self._scheduled:
            var wait = Wait.never()
            wait.interruptible = False
            return wait^
        return self._wait.copy()

    def enter(mut self, context: IOContext[Self.E]) -> Bool:
        if self._scheduled:
            self._scheduled.value().begin()
        if not self.entered and context.canceled():
            self.accept(Step[Self.T, Self.E].ready(None), context)
            return False
        self.entered = True
        self.polls += 1
        return True

    def accept(mut self, var step: Step[Self.T, Self.E], context: IOContext[Self.E]):
        if step.completed:
            self._protected_success = step._protected_success
            self._result = Optional(_settle(step^.outcome(), context, self._protected_success))
            self._program = None
            self._scheduled = None
        else:
            self._wait = step^.waiting()
            if self._scheduled:
                self._scheduled.value().arm(self._wait, context)

    def failed(self) -> Bool:
        return self.done() and (not self._result.value() or self._result.value().value().is_err())

    def take_outcome(mut self) -> Outcome[Self.T, Self.E]:
        if not self.done():
            abort("unfinished task cannot be consumed")
        return self._result.take()

    def take_step(mut self) -> Step[Self.T, Self.E]:
        # Structural forwarding preserves a masked completion; entering another
        # operation still observes cancellation at its ordinary checkpoint.
        return Step(Optional(self.take_outcome()), Wait(), self._protected_success)


def _tick[P: Machine](mut slot: _Slot[P, P.Value, P.Error], context: IOContext[P.Error]) -> Bool:
    slot.prepare(context)
    if not slot.ready(context._clock.now(), context):
        return False
    if slot.enter(context):
        var step = slot._program.value()[].poll(slot.poll_context(context))
        slot.accept(step^, context)
    return True


struct Task[P: Machine](Movable, not Deinitable):
    """Linear owner of the complete execution subtree, including cleanup."""
    var _slot: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var context: IOContext[Self.P.Error]

    def __init__(out self, var program: Self.P, token: CancellationToken):
        self._slot = _Slot[Self.P, Self.P.Value, Self.P.Error](program^)
        self.context = IOContext[Self.P.Error](token.copy(), False)
        self.context._runtime = Optional(_Runtime())
        self._slot.prepare(self.context)

    def done(self) -> Bool:
        return self._slot.done()

    def ready(self, now: Int) -> Bool:
        return self._slot.ready(now, self.context)

    def cancel(self):
        self.context.request_cancel()

    def tick(mut self) -> Bool:
        while self.context._runtime.value().fire_due(self.context._clock.now()):
            pass
        return self._poll_ready()

    def _poll_ready(mut self) -> Bool:
        return _tick(self._slot, self.context)

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        return self._slot.take_outcome()


@fieldwise_init
struct Progress(Copyable):
    var completed: Bool
    var runnable: Bool
    var deadline: Optional[Int]
    var polls: Int
    var timers: Int


struct Driver[P: Machine](Movable, not Deinitable):
    """Nonblocking host boundary; the linear owner still includes all cleanup."""
    var task: Task[Self.P]
    var _timer_turn: Bool

    def __init__(out self, var program: Self.P, token: CancellationToken, clock: Clock):
        self.task = Task(program^, token)
        self.task.context._clock = clock.copy()
        self._timer_turn = True

    def __init__(out self, var program: Self.P):
        self = Self(program^, CancellationToken(), Clock())

    def cancel(self):
        self.task.cancel()

    def poll(mut self, budget: Int) -> Progress:
        if budget < 0:
            abort("driver budget must be nonnegative")
        var polls = 0
        var timers = 0
        while polls + timers < budget and not self.task.done():
            var now = self.task.context._clock.now()
            var ready = self.task.ready(now)
            if (self._timer_turn or not ready) and self.task.context._runtime.value().fire_due(now):
                timers += 1
                self._timer_turn = False
            elif ready:
                _ = self.task._poll_ready()
                polls += 1
                self._timer_turn = True
            else:
                break
        var deadline = self.task.context._runtime.value().next_deadline()
        var ready = not self.task.done() and (self.task.ready(self.task.context._clock.now()) or (Bool(deadline) and deadline.value() <= self.task.context._clock.now()))
        return Progress(self.task.done(), ready, deadline^, polls, timers)

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        return self.task^.finish()


def _host_idle(progress: Progress):
    # Compatibility fallback only. Driver.poll never calls this function.
    if not progress.runnable and not progress.completed:
        sleep(0.001)


def run[P: Machine](var program: P, token: CancellationToken) -> Outcome[P.Value, P.Error]:
    var driver = Driver(program^, token, Clock())
    var progress = driver.poll(64)
    while not progress.completed:
        _host_idle(progress)
        progress = driver.poll(64)
    return driver^.finish()


def run[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    return run(program^, CancellationToken())


def run_pair[P: Machine, Q: Machine](var first: P, var second: Q,
    first_token: CancellationToken, second_token: CancellationToken
) -> Tuple[Outcome[P.Value, P.Error], Outcome[Q.Value, Q.Error]]:
    """Finite batch driver; each ready task gets at most one poll per round."""
    var left = Driver(first^, first_token, Clock())
    var right = Driver(second^, second_token, Clock())
    while True:
        var a = left.poll(1)
        var b = right.poll(1)
        if a.completed and b.completed:
            break
        if not a.runnable and not b.runnable:
            sleep(0.001)
    return (left^.finish(), right^.finish())


struct Sleep[E: Movable & Deinitable](Machine):
    var _duration: Int
    var _deadline: Optional[Int]
    comptime Value = NoneType
    comptime Error = Self.E

    def __init__(out self, nanoseconds: Int):
        if nanoseconds < 0 or nanoseconds > 1000000000000000000:
            abort("sleep duration outside supported range")
        self._duration = nanoseconds
        self._deadline = None

    def _start(mut self, now: Int):
        if not self._deadline:
            if now > Int.MAX - self._duration:
                abort("monotonic deadline overflow")
            self._deadline = Optional(now + self._duration)

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if context.canceled():
            return Step[NoneType, Self.E].ready(None)
        var now = context._clock.now()
        self._start(now)
        if now >= self._deadline.value():
            var unit: NoneType = None
            return Step[NoneType, Self.E].ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))
        var wait = Wait.until(self._deadline.value())
        wait.interruptible = not context._masked
        return Step[NoneType, Self.E].pending(wait^)
