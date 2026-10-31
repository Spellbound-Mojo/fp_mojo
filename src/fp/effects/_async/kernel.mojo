"""Typed resumable work with no coroutine intrinsics or context-switch ABI."""
from std.memory import OwnedPointer, ArcPointer
from std.time import sleep
from std.sys import stderr
from std.os import abort
from .time import Duration, Instant
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects._io_core import _settle, _Budget, _Reporter
from fp.data import Result, Ok
from fp._internal.waking import _Event as Signal, _Runtime, _Ticket, _Subscription, _Waker, _Clock as Clock, _Notifier
from .executor import _Executor


@fieldwise_init
struct _Wake(Copyable):
    var signal: Optional[Signal]
    var revision: UInt64
    var deadline: Optional[Instant]
    var token: Optional[CancellationToken]

    def ready(self, now: Instant) -> Bool:
        return (Bool(self.signal) and self.signal.value().revision() != self.revision
            or Bool(self.deadline) and now >= self.deadline.value()
            or Bool(self.token) and self.token.value().requested())


struct Wait(Copyable):
    """An opaque cooperative wait descriptor consumed by the runtime.

    Read a signal revision before inspecting its associated state. If still
    pending, return changed with that captured revision; registration rechecks
    it. Notification is a readiness hint, not synchronization for external work.
    Cancellation remains a wake source when the execution context allows it.
    """
    var _signal: Optional[Signal]
    var _revision: UInt64
    var _deadline: Optional[Instant]
    var _interruptible: Bool
    var _runnable: Bool
    var _wakes: List[_Wake]

    def __init__(out self):
        """Yield scheduling while remaining immediately runnable."""
        self._signal = None
        self._revision = 0
        self._deadline = None
        self._interruptible = True
        self._runnable = True
        self._wakes = List[_Wake]()

    @staticmethod
    def never() -> Self:
        """Wait without an ordinary wake source; cancellation can still wake.

        Returns:
            An opaque pending descriptor.
        """
        var wait = Self()
        wait._runnable = False
        return wait^

    def _include[E: Movable & Deinitable](mut self, other: Self, context: IOContext[E]):
        """Flatten owned descriptors, binding cancellation to its actual token."""
        self._runnable = self._runnable or other._runnable
        if other._signal or other._deadline:
            self._wakes.append(_Wake(other._signal.copy(), other._revision, other._deadline.copy(), None))
        if other._interruptible and not context._masked:
            self._wakes.append(_Wake(None, 0, None, Optional(context._token.copy())))
        for wake in other._wakes:
            self._wakes.append(wake.copy())

    @staticmethod
    def changed(signal: Signal, revision: UInt64) -> Self:
        """Wait until the shared signal differs from a captured revision.

        Args:
            signal: The shared readiness source, copied into the descriptor.
            revision: The revision captured before inspecting associated state.

        Returns:
            A wait that preserves a notification arriving before registration.
        """
        var wait = Self.never()
        wait._signal = Optional(signal.copy())
        wait._revision = revision
        return wait^

    @staticmethod
    def until(deadline: Instant) -> Self:
        """Wait until an absolute deadline in the inherited clock's origin.

        Args:
            deadline: An opaque point in the inherited clock origin.

        Returns:
            A timer wait; the host remains responsible for making progress.
        """
        var wait = Self.never()
        wait._deadline = Optional(deadline.copy())
        return wait^

    def _ready[E: Movable & Deinitable](self, now: Instant, context: IOContext[E]) -> Bool:
        if self._interruptible and context.canceled():
            return True
        if self._signal and self._signal.value().revision() != self._revision:
            return True
        if self._deadline and now >= self._deadline.value():
            return True
        for wake in self._wakes:
            if wake.ready(now):
                return True
        return self._runnable


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
        self.subscriptions.append(token._event._subscribe(revision, target))
        if token.requested():
            _ = target.wake()

    def arm[E: Movable & Deinitable](mut self, wait: Wait, context: IOContext[E]):
        if wait._runnable:
            self.runtime.arm(self.ticket, True, None)
            return
        if not wait._signal and not len(wait._wakes) and (not wait._interruptible or context._masked):
            self.runtime.arm(self.ticket, False, wait._deadline)
            return
        var target = self.runtime.waker(self.ticket)
        var deadline = wait._deadline.copy()
        if wait._signal:
            self.subscriptions.append(wait._signal.value()._subscribe(wait._revision, target))
        if wait._interruptible and not context._masked:
            self.cancel_subscription(context._token, target)
        for wake in wait._wakes:
            if wake.signal:
                self.subscriptions.append(wake.signal.value()._subscribe(wake.revision, target))
            if wake.token:
                self.cancel_subscription(wake.token.value(), target)
            if wake.deadline and (not deadline or wake.deadline.value() < deadline.value()):
                deadline = wake.deadline.copy()
        self.runtime.arm(self.ticket, wait._runnable, deadline)


struct Step[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """An opaque pending descriptor or terminal owned outcome from one poll.

    A terminal outcome certifies that entered work and cleanup are finished or
    that their ownership was transferred into the result. A machine is never
    polled after its terminal step. Runtime settlement and mask markers are
    internal; extensions construct ready or pending without manipulating them.

    Parameters:
        T: The exact owned success value, including external origins.
        E: The exact domain error stored in the canonical outcome.
    """
    # Outer absence means pending; inner absence is a completed cancellation.
    var _completed: Optional[Outcome[Self.T, Self.E]]
    var _wait: Wait
    var _protected_success: Bool

    @staticmethod
    def ready(var outcome: Outcome[Self.T, Self.E]) -> Self:
        """Transfer a terminal outcome to the runtime after discharging owned work.

        Args:
            outcome: Success, full ordered failure, or cancellation-only.

        Returns:
            A terminal step, consumed by its execution owner.
        """
        return Self._make(Optional(outcome^), Wait())

    @staticmethod
    def pending(var wait: Wait) -> Self:
        """Suspend cooperatively while retaining entered ownership in the machine.

        Args:
            wait: The owned readiness descriptor.

        Returns:
            A pending step; its machine may be polled again when runnable.
        """
        return Self._make(None, wait^)

    def _outcome(deinit self) -> Outcome[Self.T, Self.E]:
        return self._completed.take()

    def _waiting(deinit self) -> Wait:
        return self._wait^

    def __init__(out self):
        """Create a pending scheduling yield; ready and pending select explicit states."""
        self._completed = None
        self._wait = Wait()
        self._protected_success = False

    @staticmethod
    def _make(var completed: Optional[Outcome[Self.T, Self.E]], var wait: Wait, protected_success: Bool = False) -> Self:
        var step = Self()
        step._completed = completed^
        step._wait = wait^
        step._protected_success = protected_success
        return step^


trait Machine(Movable, Deinitable):
    """A concretely typed cooperative leaf; IO.lift runs one as a step of an IO.

    Declare Value and Error and a mutating poll accepting IOContext[Error] and
    returning Step[Value, Error]. Poll must return promptly; terminal steps
    discharge entered external work and cleanup. Driver and the library's
    combinators own polling. Implementations retain independent external
    origins, never a temporary per-poll context loan.
    """
    comptime Value: Movable & Deinitable
    """The owned success value."""
    comptime Error: Movable & Deinitable
    """The exact domain error."""
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        """Advance cooperatively without blocking.

        Args:
            context: The inherited cancellation and runtime context, valid for this call.

        Returns:
            A pending wait descriptor or a terminal owned outcome.
        """
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

    def ready(self, now: Instant, context: IOContext[Self.E]) -> Bool:
        if self._scheduled:
            return self._scheduled.value().runtime.ready(self._scheduled.value().ticket)
        return not self.done() and self._wait._ready(now, context)

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
            wait._interruptible = False
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
        if step._completed:
            self._protected_success = step._protected_success
            self._result = Optional(_settle(step^._outcome(), context, self._protected_success))
            self._program = None
            self._scheduled = None
        else:
            self._wait = step^._waiting()
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
        return Step[Self.T, Self.E]._make(Optional(self.take_outcome()), Wait(), self._protected_success)


def _tick[P: Machine](mut slot: _Slot[P, P.Value, P.Error], context: IOContext[P.Error]) -> Bool:
    slot.prepare(context)
    if not slot.ready(context._clock.now(), context):
        return False
    if slot.enter(context):
        var step = slot._program.value()[].poll(slot.poll_context(context))
        slot.accept(step^, context)
    return True


def _report_to_stderr(line: String):
    print(line, file=stderr)


struct IORuntimeConfig(Copyable):
    """How often IO yields to its host and checks for cancellation, and where
    unhandled fiber failures go.

    The counterpart of Cats Effect's IORuntimeConfig. Every run loop under one
    root draws from one budget of interpreter transitions per root poll and
    yields when it is spent. Bind and recovery handoffs check for cancellation
    every `cancelation_check_threshold` handoffs; leaves, masked regions and
    cleanup keep their own checkpoints. Native callback bodies, custom polls and
    destructors are not counted and cannot be preempted.

    A fiber failure that is never joined is reported once its last handle or
    join is dropped: `reporter` receives one formatted line, the errors when
    the error type is Writable, otherwise its type name and error count.
    """
    var cancelation_check_threshold: Int
    """Handoffs between cancellation checks; 1 checks every bind."""
    var auto_yield_threshold: Int
    """Interpreter transitions per root poll before yielding to the host."""
    var report_unhandled_fiber_errors: Bool
    """Whether unjoined fiber failures reach the reporter; on by default."""
    var reporter: def(String) thin
    """The host callback for unhandled fiber failures; standard error by default."""

    def __init__(out self):
        """The defaults: check every handoff, yield every 1,024 transitions, and
        report unhandled fiber failures to standard error."""
        self.cancelation_check_threshold = 1
        self.auto_yield_threshold = 1024
        self.report_unhandled_fiber_errors = True
        self.reporter = _report_to_stderr

    def __init__(out self, cancelation_check_threshold: Int, auto_yield_threshold: Int) raises:
        """Validate a configuration so that yielding never disables checks.

        Args:
            cancelation_check_threshold: Positive handoffs between cancellation checks.
            auto_yield_threshold: Positive transitions per root poll, a multiple
                of the check threshold so every yield point is a check point.

        Raises:
            Error: A threshold is not positive, or the yield threshold is not a
                multiple of the check threshold.
        """
        if cancelation_check_threshold <= 0 or auto_yield_threshold <= 0:
            raise Error("IORuntimeConfig thresholds must be positive")
        if auto_yield_threshold % cancelation_check_threshold != 0:
            raise Error("auto yield threshold must be a multiple of the cancelation check threshold")
        self.cancelation_check_threshold = cancelation_check_threshold
        self.auto_yield_threshold = auto_yield_threshold
        self.report_unhandled_fiber_errors = True
        self.reporter = _report_to_stderr


struct Task[P: Machine](Movable, not Deinitable):
    """Linear owner of the complete execution subtree, including cleanup.

    The root program is a task of the root's current-thread executor, beside
    every fiber started under it; one root poll is one executor turn.
    """
    var _slot: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var context: IOContext[Self.P.Error]
    var _executor: _Executor

    def __init__(out self, var program: Self.P, token: CancellationToken, config: IORuntimeConfig = IORuntimeConfig()):
        self._slot = _Slot[Self.P, Self.P.Value, Self.P.Error](program^)
        self.context = IOContext[Self.P.Error](token.copy(), False)
        var runtime = _Runtime()
        self.context._runtime = Optional(runtime.copy())
        self.context._budget = Optional(ArcPointer(_Budget(config.auto_yield_threshold, config.cancelation_check_threshold, config.report_unhandled_fiber_errors, config.reporter)))
        self._executor = _Executor(runtime)
        self._slot.prepare(self.context)
        # The root's registration is ready, so installing the hook queues the root.
        runtime.attach(self._executor.root)

    def done(self) -> Bool:
        return self._slot.done()

    def ready(self, now: Instant) -> Bool:
        return not self._slot.done() and self._executor.ready()

    def cancel(self):
        self.context.request_cancel()

    def tick(mut self) -> Bool:
        while self.context._runtime.value().fire_due(self.context._clock.now()):
            pass
        return self._poll_ready()

    def _poll_ready(mut self) -> Bool:
        """One root poll: an executor turn over the queued tasks, in FIFO order.

        Each poll gets a fresh slice of interpreter transitions, and the turn
        ends when it is spent, the queue is empty, or the next task already ran.
        """
        self.context._budget.value()[].refill()
        self._executor.begin_turn()
        var ran = False
        while self.context._budget.value()[].remaining > 0:
            var next = self._executor.next()
            if not next:
                break
            ran = True
            var task = next.take()
            if task[].root:
                _ = _tick(self._slot, self.context)
                _Executor.settle(task, self._slot.done())
            else:
                _Executor.run(task)
        return ran

    def _transitions(self) -> Int:
        return self.context._budget.value()[].consumed

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        # Release the shared scheduler state here, not on a thread whose late
        # wake drops the last reference (see _Scheduler.shutdown).
        self._executor.scheduler[].shutdown()
        return self._slot.take_outcome()


@fieldwise_init
struct Progress(Copyable):
    """A snapshot of root completion, readiness, and bounded scheduling work.

    Completion includes every owned child and cleanup. A pending idle root may
    need external notification or advancement to its earliest deadline. Counts
    report only the latest Driver.poll call; zero budget makes no progress.
    """
    var completed: Bool
    """Whether the complete root can be consumed with finish."""
    var runnable: Bool
    """Whether polling can currently advance work without host waiting."""
    var deadline: Optional[Instant]
    """The earliest live deadline, if any, in the inherited clock origin."""
    var polls: Int
    """Root polls performed during this call."""
    var timers: Int
    """Due timer events fired during this call."""
    var transitions: Int
    """IO interpreter transitions run during this call, across nested run loops."""
    var quiescent: Bool
    """Not completed, nothing runnable, and no live deadline: awaiting external input."""


struct Driver[P: Machine](Movable, not Deinitable):
    """Nonblocking host boundary; the linear owner still includes all cleanup."""
    var task: Task[Self.P]
    var _timer_turn: Bool

    def __init__(out self, var program: Self.P, token: CancellationToken, clock: Clock, config: IORuntimeConfig = IORuntimeConfig()):
        self.task = Task(program^, token, config)
        self.task.context._clock = clock.copy()
        self._timer_turn = True

    def __init__(out self, var program: Self.P):
        self = Self(program^, CancellationToken(), Clock())

    def __init__(out self, var program: Self.P, token: CancellationToken, clock: Clock, config: IORuntimeConfig, var notifier: _Notifier):
        """Own a program whose external wakes are reported through a host notifier.

        The notifier is installed after the root is queued, so only wakes
        delivered while no poll runs reach it.
        """
        self = Self(program^, token, clock, config)
        self.task._executor.scheduler[].notifier = Optional(notifier^)

    def cancel(self):
        self.task.cancel()

    @staticmethod
    def _valid_budget(budget: Int) -> Bool:
        return budget >= 0

    def poll(mut self, budget: Int) -> Progress:
        if not Self._valid_budget(budget):
            abort("driver budget must be nonnegative")
        var polls = 0
        var timers = 0
        var before = self.task._transitions()
        var scheduler = self.task._executor.scheduler.copy()
        scheduler[].set_polling(True)
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
        # Cleared before reading readiness: a wake queued after this reads
        # notifies the host (see _Scheduler.push).
        scheduler[].set_polling(False)
        var deadline = self.task.context._runtime.value().next_deadline()
        var ready = not self.task.done() and (self.task.ready(self.task.context._clock.now()) or (Bool(deadline) and deadline.value() <= self.task.context._clock.now()))
        var done = self.task.done()
        var quiescent = not done and not ready and not deadline
        return Progress(done, ready, deadline^, polls, timers, self.task._transitions() - before, quiescent)

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        # The notifier is never called after this returns: the task's finish
        # closes it and waits for a call in flight.
        return self.task^.finish()


def _host_idle(progress: Progress):
    # Compatibility fallback only. Driver.poll never calls this function.
    if not progress.runnable and not progress.completed:
        sleep(0.001)


def run[P: Machine](var program: P, token: CancellationToken, config: IORuntimeConfig = IORuntimeConfig()) -> Outcome[P.Value, P.Error]:
    var driver = Driver(program^, token, Clock(), config)
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
    var _deadline: Optional[Instant]
    comptime Value = NoneType
    comptime Error = Self.E

    def __init__(out self, nanoseconds: Int):
        if not Duration._valid_scaled[1](nanoseconds):
            abort("sleep duration outside supported range")
        self._duration = nanoseconds
        self._deadline = None

    def _start(mut self, now: Instant):
        if not self._deadline:
            self._deadline = Optional(now._after_nanoseconds(self._duration))

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if context.canceled():
            return Step[NoneType, Self.E].ready(None)
        var now = context._clock.now()
        self._start(now)
        if now >= self._deadline.value():
            var unit: NoneType = None
            return Step[NoneType, Self.E].ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))
        var wait = Wait.until(self._deadline.value())
        wait._interruptible = not context._masked
        return Step[NoneType, Self.E].pending(wait^)
