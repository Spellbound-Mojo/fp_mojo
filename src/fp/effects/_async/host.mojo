"""Checked host boundaries over canonical clock, driver and nursery owners."""
from fp.effects import CancellationToken, Outcome, IOContext
from fp._internal.waking import _Clock
from fp._internal.time import Instant
from .kernel import Machine, Driver as _Driver, Progress, Step, run as _run
from .nurseries import Nursery as _Nursery, Spawner


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
    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        """Consume a completed root exactly once.

        Returns:
            Its owned success, complete ordered failure, or cancellation outcome.
            Calling before completion is a protocol violation.
        """
        return self._driver^.finish()


struct Nursery[P: Machine](Machine):
    """Own a bounded lifetime total of accepted children of one exact type.

    Parameters:
        P: The child machine type, including all payload, error and capture origins.
    """
    comptime Value = List[Self.P.Value]
    """Successful child values in admission order."""
    comptime Error = Self.P.Error
    """The exact child domain error."""
    var _nursery: _Nursery[Self.P]
    def __init__(out self, limit: Int) raises:
        """Create an unopened nursery with checked total admission capacity.

        Args:
            limit: Maximum lifetime accepted children; zero is a valid empty bound.

        Raises:
            Error: A negative admission limit, before allocating an owner.
        """
        if not _Nursery[Self.P]._valid_limit(limit):
            raise Error("nursery admission limit must be nonnegative")
        self._nursery = _Nursery[Self.P](limit)
    def spawner(self) -> Spawner[Self.P]:
        """Copy the submission capability; accepted children stay owned here.

        Returns:
            A handle supporting try_spawn and close, without detach or joining.
        """
        return self._nursery.spawner()
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        """Advance the canonical nursery engine under the inherited context.

        Args:
            context: Runtime cancellation, mask and clock handles.

        Returns:
            A pending wait or the settled subtree outcome.
        """
        return self._nursery.poll(context)


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
