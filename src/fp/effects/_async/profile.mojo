"""Execution profiles: where a runtime runs fibers, and the one owner of the default.

`Profile` is a leaf module so that `IORuntimeConfig` (`kernel.mojo`) can hold
one without importing the pool, which imports the kernel. `Runtime`
(`runtime.mojo`) and the free `run` (`host.mojo`) read it.

The default profile has one owner, `_default_profile()`. It is
the work-stealing profile with one worker per logical processor, except on
a host with one logical processor, where it is the current-thread profile:
a one-worker pool would pay the pool's costs with nothing to run in
parallel. The choice is the `_AUTO` sentinel, resolved when the profile is
read (`_concrete`), so a default `IORuntimeConfig()` folds at compile time
and `num_logical_cores()` runs only at run time.

Building with `-D FP_ASYNC_PROFILE=current_thread` makes the default the
current-thread profile, the default before the work-stealing pool; `-D
FP_ASYNC_PROFILE=work_stealing` makes it the work-stealing profile with one
worker per logical processor even on one processor; and `-D
FP_ASYNC_WORKERS=n` sets that pool's size. These overrides exist for
qualification, which runs every client on both profiles. A profile set
explicitly in `IORuntimeConfig.profile` always wins over the define and the
resolution.
"""
from std.sys.defines import get_defined_int, get_defined_string
from std.sys.info import num_logical_cores

comptime _MAX_WORKERS = 1 << 15
"""The largest work-stealing pool, bounded by the pool's packed state word."""

comptime _PROFILE = get_defined_string["FP_ASYNC_PROFILE", "default"]()
"""The qualification override of the default profile: `current_thread`, `work_stealing`, or `default` when none is given."""

comptime _WORKERS = get_defined_int["FP_ASYNC_WORKERS", 0]()
"""The override's pool size; 0 means one worker per logical processor."""


comptime _PER_CORE = -1
"""A work-stealing profile with one worker per logical processor, counted when the profile is read."""

comptime _AUTO = -2
"""The default: the current-thread profile on one logical processor, else `_PER_CORE`, decided when the profile is read."""


def _default_workers() -> Int:
    """One worker per online logical processor, at least one."""
    return min(max(1, num_logical_cores()), _MAX_WORKERS)


struct Profile(Copyable, Equatable, Writable):
    """Where a runtime runs fibers: on the calling thread, or on a work-stealing pool.

    The current-thread profile runs every fiber of a root on the thread that
    runs the root, in a deterministic FIFO order. The work-stealing profile,
    after Cats Effect's work-stealing thread pool, runs fibers in parallel on
    worker threads that steal each other's queued work; fibers then share
    mutable state only through synchronized owners such as `Ref` (see the
    guide's thread-safety section). Set it in `IORuntimeConfig.profile`.
    `Driver` and `TestControl` always use the current-thread profile.

    The default profile (`IORuntimeConfig()`) is the work-stealing one with a
    worker per logical processor, and the current-thread one on a host with
    a single logical processor. It is decided when it is read, so
    `is_work_stealing`, `workers`, equality and the written form report the
    profile a program would run on here; an explicit `current_thread()` or
    `work_stealing(n)` is never changed.
    """
    var _workers: Int
    """Worker threads of the work-stealing profile; 0 for the current-thread
    profile; `_PER_CORE` for one per logical processor, read at run time;
    `_AUTO` for the default, resolved at run time (`_concrete`)."""

    def __init__(out self, *, _workers: Int):
        self._workers = _workers

    @staticmethod
    def current_thread() -> Self:
        """Run every fiber of a root on the thread that runs it, in deterministic FIFO order.

        Returns:
            The current-thread profile.
        """
        return Self(_workers=0)

    @staticmethod
    def work_stealing() raises -> Self:
        """Run fibers in parallel on one worker thread per logical processor.

        The processor count is read when this is called. (Mojo evaluates a
        default argument at compile time, so this is an overload rather than
        a default of `workers`.)

        Returns:
            The work-stealing profile with one worker per logical processor.

        Raises:
            Error: Never in practice: the count is clamped to 1 to 32768. The
                signature matches the overload taking `workers`.
        """
        return Self.work_stealing(_default_workers())

    @staticmethod
    def work_stealing(workers: Int) raises -> Self:
        """Run fibers in parallel on worker threads that steal each other's work.

        Args:
            workers: The number of worker threads, from 1 to 32768.

        Returns:
            The work-stealing profile with that many workers.

        Raises:
            Error: `workers` is outside 1 to 32768.
        """
        if workers < 1 or workers > _MAX_WORKERS:
            raise Error("Profile.work_stealing needs 1 to 32768 workers")
        return Self(_workers=workers)

    def _resolved(self, cores: Int) -> Self:
        """This profile as it runs on a host with `cores` logical processors.

        The one place a deferred profile is decided; `_concrete` passes the
        host's count, and tests pass any count. `_AUTO` becomes the
        current-thread profile for one processor and a pool of `cores`
        workers otherwise; `_PER_CORE` becomes a pool of `cores` workers;
        every other profile is returned as it is.
        """
        var counted = min(max(1, cores), _MAX_WORKERS)
        if self._workers == _AUTO:
            return Self(_workers=0 if counted == 1 else counted)
        if self._workers == _PER_CORE:
            return Self(_workers=counted)
        return Self(_workers=self._workers)

    def _concrete(self) -> Self:
        """This profile on this host; reads the processor count only for a deferred profile."""
        if self._workers >= 0:
            return Self(_workers=self._workers)
        return self._resolved(num_logical_cores())

    def is_work_stealing(self) -> Bool:
        """Report whether this profile runs a work-stealing pool.

        The default resolves first: on a host with one logical processor it
        is the current-thread profile.

        Returns:
            True for `work_stealing`, False for `current_thread`.
        """
        return self._concrete()._workers != 0

    def workers(self) -> Int:
        """Report how many threads run fibers.

        Returns:
            The pool's workers, or 1 for the current-thread profile.
        """
        var concrete = self._concrete()
        return concrete._workers if concrete._workers != 0 else 1

    def __eq__(self, other: Self) -> Bool:
        if self.is_work_stealing() != other.is_work_stealing():
            return False
        return self.workers() == other.workers()

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def write_to(self, mut writer: Some[Writer]):
        """Write `current_thread` or `work_stealing(n)`.

        Args:
            writer: The destination.
        """
        if not self.is_work_stealing():
            writer.write("current_thread")
        else:
            writer.write("work_stealing(", self.workers(), ")")


def _default_profile() -> Profile:
    """The default profile, the one owner of it (see the module docstring)."""
    # Folded at compile time wherever a default `IORuntimeConfig()` argument
    # appears, so the processor count is read later (`_concrete`);
    # `num_logical_cores()` cannot run at compile time.
    comptime if _PROFILE == "default":
        return Profile(_workers=_AUTO)
    elif _PROFILE == "work_stealing":
        return Profile(_workers=_WORKERS if _WORKERS > 0 else _PER_CORE)
    else:
        comptime assert _PROFILE == "current_thread", "FP_ASYNC_PROFILE must be current_thread or work_stealing"
        return Profile.current_thread()
