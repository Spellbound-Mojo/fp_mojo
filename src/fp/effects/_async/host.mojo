"""Checked host boundaries over canonical clock and driver owners."""
from std.builtin.rebind import downcast
from std.os import abort
from fp.effects import CancellationToken, Outcome, IOContext
from fp._internal.waking import _Clock
from fp._internal.time import Duration, Instant
from .kernel import Machine, Driver as _Driver, Progress, Step, IORuntimeConfig, run as _run
from .fibers import FiberInfo, _FiberHost


struct Clock(Copyable):
    """A shared monotonic clock with checked deterministic host operations."""
    var _clock: _Clock
    def __init__(out self):
        """Create a clock reading the host monotonic time source."""
        self._clock = _Clock()
    @staticmethod
    def manual(now: Int = 0) raises -> Self:
        """Create shared deterministic time before entering a root.

        Args:
            now: Initial nonnegative nanoseconds, zero by default.

        Returns:
            A copyable handle whose copies observe the same time.

        Raises:
            Error: The initial time is negative.
        """
        if not _Clock._valid_manual(now):
            raise Error("manual clock must be nonnegative")
        var clock = Self()
        clock._clock = _Clock.manual(now)
        return clock^
    def now(self) -> Instant:
        """Read the current opaque monotonic point.

        Returns:
            Time in this clock's origin, not a wall-clock timestamp.
        """
        return self._clock.now()
    def advance_to(self, now: Instant) raises:
        """Atomically advance a manual clock; rejected updates change nothing.

        Args:
            now: A point in this clock origin, at least as late as its current time.

        Raises:
            Error: This is a system clock, or the update would move time backward.
        """
        if not self._clock._try_advance_to(now):
            raise Error("only a manual clock can advance monotonically")


struct Driver[P: Machine](Movable, not Deinitable):
    """A linear root owner that advances cooperative work without host sleeping.

    Request cancellation, then keep polling until completed before consuming
    finish. No detach or abandoning destructor exists. Entered external work and
    cleanup must finish before terminal status; callbacks must return cooperatively.

    Parameters:
        P: The concrete application machine, retaining native payload origins.
    """
    var _driver: _Driver[Self.P]
    def __init__(out self, var program: Self.P):
        """Own a program with a fresh token and monotonic clock.

        Args:
            program: The unopened recipe, consumed once.
        """
        self._driver = _Driver(program^)
    def __init__(out self, var program: Self.P, token: CancellationToken, clock: Clock):
        """Own a program using supplied shared cancellation and time handles.

        Args:
            program: The unopened recipe, consumed once.
            token: The shared cancellation request handle, copied.
            clock: The shared runtime clock, copied.
        """
        self._driver = _Driver(program^, token, clock._clock)
    def __init__(out self, var program: Self.P, token: CancellationToken, clock: Clock, config: IORuntimeConfig):
        """Own a program with supplied handles and an interpreter configuration.

        Args:
            program: The unopened program, consumed once.
            token: The shared cancellation request handle, copied.
            clock: The shared runtime clock, copied.
            config: How often IO yields and checks for cancellation.
        """
        self._driver = _Driver(program^, token, clock._clock, config)
    def request_cancel(self):
        """Request cancellation; continue polling to join all work and cleanup."""
        self._driver.cancel()
    def poll(mut self) -> Progress:
        """Advance with a fixed budget of 64; this overload raises no setup error.

        Returns:
            Root completion, readiness, earliest deadline and work counts.
        """
        return self._driver.poll(64)
    def poll(mut self, budget: Int) raises -> Progress:
        """Advance at most the supplied number of root polls plus timer events.

        Args:
            budget: A nonnegative work count; zero only observes status.

        Returns:
            Completion and readiness including all owned descendants and cleanup.

        Raises:
            Error: A negative budget, before progress or ownership changes. Catch
                while retaining this owner, then continue polling to completion.
        """
        if not _Driver[Self.P]._valid_budget(budget):
            raise Error("driver budget must be nonnegative")
        return self._driver.poll(budget)
    def fibers(self) -> List[FiberInfo]:
        """List the live fibers the root IO hosts, between polls.

        A bounded diagnostic view, like Cats Effect's fiber dump: each entry
        names an internal slot, its owner's slot, and whether it is runnable,
        suspended, or draining its children. It holds no payloads and no
        completed fibers. The sides of both and races are fibers of the root
        and are listed; an IO lifted into a leaf with IO.lift hosts its own
        fibers, which are not.

        Returns:
            The live fibers in slot order; empty for a root that is not an IO,
            before the first start, and after completion.
        """
        comptime if conforms_to(Self.P, _FiberHost):
            ref program = self._driver.task._slot._program
            if program:
                var now = self._driver.task.context._clock.now()
                return rebind[downcast[Self.P, _FiberHost]](program.value()[])._fiber_snapshot(now)
        return List[FiberInfo]()

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        """Consume a completed root exactly once.

        Returns:
            Its owned success, complete ordered failure, or cancellation outcome.
            Calling before completion is a protocol violation.
        """
        return self._driver^.finish()


struct TestControl[P: Machine](Movable, not Deinitable):
    """Run a program on virtual time, as Cats Effect's TestControl.

    The program runs on a manual clock that starts at zero and moves only when
    the test advances it, so sleeps and timeouts complete without real waiting.
    `tick` runs everything runnable without moving time; `advance` moves time
    without running anything; `tick_all` alternates the two until the program
    completes or nothing is scheduled. External events, such as completing an
    IO.async registration or a shared Deferred, are observed at the next tick;
    when several fibers become ready together, their order is unspecified.
    Like Driver, the control owns the program linearly: request cancellation
    and tick until it completes before taking its results.

    Parameters:
        P: The program, an IO or a custom machine.
    """
    var _driver: Driver[Self.P]
    var _clock: Clock

    def __init__(out self, var program: Self.P):
        """Own a program on a fresh manual clock at zero.

        Args:
            program: The unopened program, consumed once.
        """
        self = Self(program^, IORuntimeConfig())

    def __init__(out self, var program: Self.P, config: IORuntimeConfig):
        """Own a program on a fresh manual clock at zero, with a configuration.

        Args:
            program: The unopened program, consumed once.
            config: How often IO yields and checks for cancellation.
        """
        var clock = Clock()
        clock._clock = _Clock.manual(0)
        self._driver = Driver(program^, CancellationToken(), clock, config)
        self._clock = clock^

    def now(self) -> Instant:
        """Read virtual time.

        Returns:
            The manual clock's current point.
        """
        return self._clock.now()

    def tick_one(mut self) -> Bool:
        """Take one root poll without advancing time.

        Returns:
            Whether the poll ran any work.
        """
        var progress = self._poll(1)
        return progress.polls > 0 or progress.timers > 0

    def tick(mut self):
        """Run until nothing is runnable, without advancing time."""
        while True:
            var progress = self._poll(64)
            if progress.completed or not progress.runnable:
                return

    def advance(mut self, duration: Duration):
        """Move virtual time forward without running anything.

        Args:
            duration: How far to move.
        """
        try:
            self._clock.advance_to(self._clock.now() + duration)
        except:
            abort("a manual clock advances forward")

    def advance_and_tick(mut self, duration: Duration):
        """Move virtual time forward, then run until nothing is runnable.

        Args:
            duration: How far to move.
        """
        self.advance(duration)
        self.tick()

    def next_interval(mut self) -> Optional[Duration]:
        """Report how far virtual time must move to reach the next deadline.

        Returns:
            The duration to the earliest live deadline, or None without one.
        """
        var progress = self._poll(0)
        if not progress.deadline:
            return None
        return Optional(progress.deadline.value().since(self._clock.now()))

    def tick_for(mut self, duration: Duration):
        """Run and advance through every deadline within a duration, then to its end.

        Args:
            duration: How far virtual time moves in total.
        """
        var target = self._clock.now() + duration
        self.tick()
        while True:
            var progress = self._poll(0)
            if progress.completed or not progress.deadline or progress.deadline.value() > target:
                break
            self._advance_to(progress.deadline.value())
            self.tick()
        self._advance_to(target)
        self.tick()

    def tick_all(mut self):
        """Tick and advance to each next deadline until the program completes or none remains."""
        self.tick()
        while True:
            var progress = self._poll(0)
            if progress.completed or not progress.deadline:
                return
            self._advance_to(progress.deadline.value())
            self.tick()

    def is_completed(mut self) -> Bool:
        """Report whether the program and all its cleanup have finished.

        Returns:
            True once results can be taken.
        """
        return self._poll(0).completed

    def is_deadlocked(mut self) -> Bool:
        """Report whether the program can never continue.

        As in Cats Effect, this assumes nothing outside the program delivers
        events except through IO.async: a program waiting on a Deferred that
        the test could still complete also reports true.

        Returns:
            True when the program is incomplete, nothing is runnable, no
            deadline is live, and no IO.async registration awaits completion.
        """
        var progress = self._poll(0)
        return progress.quiescent and self._registrations() == 0

    def request_cancel(self):
        """Request cancellation; keep ticking until the program completes."""
        self._driver.request_cancel()

    def results(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        """Take the outcome of a completed program, exactly once.

        Returns:
            Its owned success, complete ordered failure, or cancellation.
            Calling before completion is a protocol violation.
        """
        return self._driver^.finish()

    def _poll(mut self, budget: Int) -> Progress:
        try:
            return self._driver.poll(budget)
        except:
            abort("a nonnegative budget is accepted")

    def _advance_to(self, point: Instant):
        try:
            self._clock.advance_to(point)
        except:
            abort("a manual clock advances forward")

    def _registrations(self) -> Int:
        ref budget = self._driver._driver.task.context._budget
        if not budget:
            return 0
        return budget.value()[].registrations


def run[P: Machine](var program: P, token: CancellationToken) -> Outcome[P.Value, P.Error]:
    """Block until self-contained work and cleanup finish under the supplied token.

    Parameters:
        P: The exact machine type and its native origins.

    Args:
        program: The unopened recipe, consumed once.
        token: Shared cancellation requests; requests do not themselves join.

    Returns:
        The owned terminal outcome. Idle work uses the canonical 1 ms sleep
        fallback; host-delivered events normally use Driver directly.
    """
    return _run(program^, token)


def run[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    """Block on self-contained work with a fresh cancellation token."""
    return _run(program^)


def run[P: Machine](var program: P, token: CancellationToken, config: IORuntimeConfig) -> Outcome[P.Value, P.Error]:
    """Block until work and cleanup finish under a token and an interpreter configuration.

    Parameters:
        P: The exact machine type and its native origins.

    Args:
        program: The unopened program, consumed once.
        token: Shared cancellation requests.
        config: How often IO yields and checks for cancellation.

    Returns:
        The owned terminal outcome.
    """
    return _run(program^, token, config)


def run[P: Machine](var program: P, config: IORuntimeConfig) -> Outcome[P.Value, P.Error]:
    """Block on self-contained work with a fresh token and an interpreter configuration.

    Parameters:
        P: The exact machine type and its native origins.

    Args:
        program: The unopened program, consumed once.
        config: How often IO yields and checks for cancellation.

    Returns:
        The owned terminal outcome.
    """
    return _run(program^, CancellationToken(), config)
