"""Checked host boundaries over canonical clock and driver owners."""
from std.builtin.rebind import downcast
from std.os import abort
from std.memory import OwnedPointer
from fp.effects import CancellationToken, Outcome, IOContext
from fp._internal.waking import _Clock, _Notifier
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.callables.protocols import Thunk
from fp.callables._receiver import _thunk_repeated_as
from fp._internal.time import Duration, Instant
from fp._internal.os import OSError
from .kernel import Machine, Driver as _Driver, Progress, Step, IORuntimeConfig, run as _run
from .fibers import FiberInfo, _fiber_infos
from fp._internal.thread_safety import ThreadTransferable
from .pool import _run_pooled
from .executor import ScheduleTrace, _Explorer


def _run_profile[P: Machine](var program: P, token: CancellationToken, config: IORuntimeConfig) -> Outcome[P.Value, P.Error]:
    """Every public `run` overload's one body: the configuration's profile, chosen at run time.

    The work-stealing profile runs on a pool made for the call, with the
    calling thread as worker 0 and the other workers started only when there
    is work to steal (`_run_pooled`), so a program that starts no fiber starts
    no thread. The default profile, the work-stealing one, has one
    owner, `_default_profile()` (`profile.mojo`), which `-D FP_ASYNC_PROFILE`
    overrides for qualification.
    `Driver`, `TestControl` and `run_pair` always use the current-thread
    profile.
    """
    # Resolved once: the default reads the processor count (`Profile._concrete`).
    var profile = config.profile._concrete()
    if profile.is_work_stealing():
        return _run_pooled(program^, token, config, profile.workers())
    return _run(program^, token, config)


struct Clock(Copyable, ThreadTransferable):
    """A shared runtime clock with checked deterministic host operations.

    The system clock reads monotonic time for Instant and CLOCK_REALTIME for
    IO.real_time. A manual clock drives both: its wall time is the Unix epoch
    plus its monotonic reading, so the two move together.
    """
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
    def __init__[N: Thunk](out self, var program: Self.P, token: CancellationToken, clock: Clock, config: IORuntimeConfig, var notifier: N) where _ErrorCompatible[Never, N.Error]:
        """Own a program and learn of external wakes through a host notifier.

        The driver calls the notifier when an event delivered while no poll
        runs, such as completing an IO.async registration or notifying a
        Signal, makes the root runnable, so a host with its own event loop can
        schedule the next poll instead of polling on a timer. The call may come
        from any thread that delivers such an event; the host asserts the
        notifier is safe there. It must return promptly and must not reenter
        this driver. Work that becomes runnable during a poll is reported by the
        poll's Progress instead. The notifier is never called after finish
        returns: finish waits for a call in progress.

        Parameters:
            N: A repeatable, non-raising callable; its result is ignored.

        Args:
            program: The unopened program, consumed once.
            token: The shared cancellation request handle, copied.
            clock: The shared runtime clock, copied.
            config: How often IO yields and checks for cancellation.
            notifier: The host's wake callback, consumed.
        """
        self._driver = _Driver(program^, token, clock._clock, config, _Notifier(_Erased(notifier^), _notify_host[N]))
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
    def park(mut self, timeout: Optional[Duration] = None) raises OSError:
        """Wait until the root may have work, without spinning; poll next.

        Returns at once when the root is completed or runnable, or its earliest
        deadline is due. Otherwise the calling thread waits in the root's
        poller until the first of: the earliest deadline, measured on this
        driver's clock (with a manual clock, in virtual time, which does not
        move while parked); an external wake, such as completing an IO.async
        registration, notifying a Signal or requesting cancellation, from any
        thread; a descriptor awaited with `await_readable` or `await_writable`
        becoming ready; or `timeout`. With no timeout, a root that nothing can
        wake waits forever, as in Cats Effect. A return may be spurious: poll,
        and park again while the program is not runnable.

        The poller's self-pipe is opened on the first park or descriptor wait,
        so a driver that never parks opens none. Readiness found while parked
        does not call the host notifier, since the host is the one parked.

        Args:
            timeout: The longest wait the host allows; None imposes no limit.

        Raises:
            OSError: The self-pipe could not be opened, or `poll` failed. The
                driver is unchanged: keep polling it to completion.
        """
        self._driver.park(timeout)

    def fibers(self) -> List[FiberInfo]:
        """List the live fibers under the root, between polls.

        A bounded diagnostic view, like Cats Effect's fiber dump: each entry
        names an internal slot, its owner's slot, and whether it is runnable,
        suspended, or draining its children. It holds no payloads and no
        completed fibers. Every fiber the root runs is listed, including the
        sides of both and races and fibers started by an IO lifted into a leaf,
        which belong to the fiber running that leaf.

        Returns:
            The live fibers in slot order; empty before the first start and
            after completion.
        """
        return _fiber_infos(self._driver.task._executor.scheduler[].snapshot())

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        """Consume a completed root exactly once.

        Returns:
            Its owned success, complete ordered failure, or cancellation outcome.
            Calling before completion is a protocol violation.
        """
        return self._driver^.finish()


def _notify_host[N: Thunk](mut target: _Erased) where _ErrorCompatible[Never, N.Error]:
    # Only the constructor that erased an N pairs this cast.
    _ = _thunk_repeated_as[Never, N](target.pointer[N]()[])


struct TestControl[P: Machine](Movable, not Deinitable):
    """Run a program on virtual time, as Cats Effect's TestControl.

    The program runs on a manual clock that starts at zero and moves only when
    the test advances it, so sleeps and timeouts complete without real waiting.
    Its wall clock, read by IO.real_time, starts at the Unix epoch and moves
    with virtual time, as in Cats Effect.
    `tick` runs everything runnable without moving time; `advance` moves time
    without running anything; `tick_all` alternates the two until the program
    completes or nothing is scheduled. External events, such as completing an
    IO.async registration or a shared Deferred, are observed at the next tick;
    when several fibers become ready together, their order is unspecified.
    Like Driver, the control owns the program linearly: request cancellation
    and tick until it completes before taking its results.

    By default the fibers ready together run in FIFO order, deterministically.
    Constructed with `seed=`, the control explores: the seed chooses the order
    of each group of fibers ready together, and `trace` records the choices,
    so a failing run can be reproduced with `replay=`. The promised orders do
    not change: a fiber's own steps, FIFO Queue values, the left side of a
    race whose sides finish together, and every Deferred reader receiving
    the value.

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

    def __init__(out self, var program: Self.P, *, seed: UInt64):
        """Own a program on virtual time and explore its unspecified orders with a seed.

        Args:
            program: The unopened program, consumed once.
            seed: Chooses the order of the fibers ready together; the same
                seed and program run the same way.
        """
        self = Self(program^, IORuntimeConfig(), replay=ScheduleTrace(seed))

    def __init__(out self, var program: Self.P, config: IORuntimeConfig, *, seed: UInt64):
        """Own a program with a configuration and explore its unspecified orders with a seed.

        Args:
            program: The unopened program, consumed once.
            config: How often IO yields and checks for cancellation.
            seed: Chooses the order of the fibers ready together.
        """
        self = Self(program^, config, replay=ScheduleTrace(seed))

    def __init__(out self, var program: Self.P, *, replay: ScheduleTrace):
        """Own a program and repeat a recorded exploration.

        Args:
            program: The unopened program, consumed once.
            replay: A trace from `trace`, or parsed from its printed form.
                Its choices are repeated, then the run continues as its seed
                would. A run whose candidates differ from the trace's aborts,
                naming the choice.
        """
        self = Self(program^, IORuntimeConfig(), replay=replay)

    def __init__(out self, var program: Self.P, config: IORuntimeConfig, *, replay: ScheduleTrace):
        """Own a program with a configuration and repeat a recorded exploration.

        Args:
            program: The unopened program, consumed once.
            config: How often IO yields and checks for cancellation.
            replay: The trace to repeat, as for the overload without a configuration.
        """
        self = Self(program^, config)
        self._driver._driver.task._executor.explorer = Optional(OwnedPointer(_Explorer(replay.copy())))

    def trace(self) -> Optional[ScheduleTrace]:
        """Report the seed and the choices made so far.

        Returns:
            The trace of an exploring control, which replays this run with
            `replay=`; None for a deterministic one.
        """
        if not self._driver._driver.task._executor.explorer:
            return None
        return Optional(self._driver._driver.task._executor.explorer.value()[].trace.copy())

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
        return self._driver._driver.task._executor.scheduler[].registered()


def run[P: Machine](var program: P, token: CancellationToken) -> Outcome[P.Value, P.Error]:
    """Block until self-contained work and cleanup finish under the supplied token.

    Parameters:
        P: The exact machine type and its native origins.

    Args:
        program: The unopened recipe, consumed once.
        token: Shared cancellation requests; requests do not themselves join.

    Returns:
        The owned terminal outcome. While nothing is runnable, the thread
        parks in the root's poller (`Driver.park`) until the next deadline, an
        external wake, or a ready descriptor, so an idle program uses no CPU.
    """
    return _run_profile(program^, token, IORuntimeConfig())


def run[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    """Block on self-contained work with a fresh cancellation token."""
    return _run_profile(program^, CancellationToken(), IORuntimeConfig())


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
    return _run_profile(program^, token, config)


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
    return _run_profile(program^, CancellationToken(), config)
