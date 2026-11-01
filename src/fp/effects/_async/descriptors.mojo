"""Descriptor readiness: an IO that waits in a poller until a descriptor is ready.

After Cats Effect's `FileDescriptorPoller`, at its lowest level: library
authors build pipes, sockets or process I/O on top, and no socket API is
published. The machine registers interest with the poller of the thread
running it and suspends on a fresh `Signal` the poller notifies once:

- On the current-thread profile, the root's poller
  (`fp.effects._async.polling`'s root slot), created on the first wait and
  used only on the thread driving the root. `Driver.poll` checks it without
  waiting whenever a descriptor is watched, and `Driver.park` (so `run`)
  waits in it. Under TestControl, readiness is seen at the next tick.
- On a work-stealing pool, the running worker's own poller, which the worker waits in when it parks and checks without
  waiting when it fires its timers. Readiness wakes the fiber through its
  signal's subscription, as any wake, so the fiber may then run on another
  worker. Finishing there releases the registration across threads
  (`_release_registration`): the registration's word is marked and counted,
  and the owner removes it at its next poll. A registration still armed also
  interrupts its owner, so that it stops watching the descriptor at once.

The caller owns the descriptor, keeping it open and nonblocking until the IO
completes. Hang-up, error and invalid-descriptor conditions count as ready,
as for `Interruption`'s waits: the caller finds them by reading or writing.
Cancellation completes the IO canceled and removes the registration; a mask
waits for readiness. Readiness is reported once per IO, so each wait
registers again.
"""
from std.ffi import c_int
from std.memory import ArcPointer
from std.os import abort
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure
from fp._internal.waking import Signal, _Scheduler
from .kernel import Machine, Step, Wait
from .engine import IO
from .polling import _Poller, _Registration, _root_poller, _existing_root_poller, _release_registration, READ_INTEREST, WRITE_INTEREST
from .pool import _worker_poller


def _running_poller(scheduler: ArcPointer[_Scheduler], create: Bool) -> Int:
    """The address of the calling thread's poller for this root, 0 when it has none.

    The root's poller on the current-thread profile; the running worker's on
    a pool, and 0 off the pool's workers. With `create`, it is opened on
    first use; failing to open it aborts.
    """
    if scheduler[].pooled():
        return _worker_poller(scheduler, create)
    if not create:
        var existing = _existing_root_poller(scheduler)
        return Int(existing.value()) if existing else 0
    try:
        return Int(_root_poller(scheduler))
    except error:
        abort(String("fp.effects: could not open the root's poller: ", error))


def _finish_registration(scheduler: ArcPointer[_Scheduler], owner: Int, shared: Int, registration: _Registration) -> Bool:
    """Remove a registration; True when the poll it reports had observed readiness.

    On its poller's owner thread the registration is read and removed at
    once; elsewhere it is released for the owner to remove.
    """
    if _running_poller(scheduler, False) == owner:
        var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=owner)
        var readiness = poller[].readiness(registration)
        _ = poller[].deregister(registration)
        return not readiness.pending()
    if not scheduler[].pooled():
        # The root's poller is gone, and its registrations with it.
        return True
    return _release_registration(shared, registration)


struct _AwaitDescriptor[E: Movable & Deinitable](Machine):
    """Wait until a descriptor is ready for the interest, then complete with unit."""
    comptime Value = NoneType
    comptime Error = Self.E
    var _fd: c_int
    var _interest: Int16
    var _signal: Signal
    var _registration: Optional[_Registration]
    # While registered: the poller's address and its registration words
    # (`_Poller.shared`), and the root's scheduler, which outlives them.
    var _owner: Int
    var _shared: Int
    var _scheduler: Optional[ArcPointer[_Scheduler]]

    def __init__(out self, fd: RawFileDescriptor, interest: Int16):
        if fd.value < 0:
            abort("fp.effects: await_readable and await_writable need an open descriptor")
        self._fd = c_int(fd.value)
        self._interest = interest
        self._signal = Signal()
        self._registration = None
        self._owner = 0
        self._shared = 0
        self._scheduler = None

    def __deinit__(deinit self):
        # A machine is polled to its terminal step, which deregisters; this
        # covers a machine dropped while registered.
        if self._registration and self._scheduler:
            _ = _finish_registration(self._scheduler.value(), self._owner, self._shared, self._registration.value())

    def _finish(mut self) -> Bool:
        """Deregister; True when the poll it reports had observed readiness."""
        var observed = _finish_registration(self._scheduler.value(), self._owner, self._shared, self._registration.value())
        self._registration = None
        return observed

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if context.canceled():
            if self._registration:
                _ = self._finish()
            return Step[NoneType, Self.E].ready(None)
        # Read before inspecting readiness; registration compares it.
        var revision = self._signal.revision()
        if not self._registration:
            if not context._runtime:
                abort("fp.effects: descriptor waits run only under a Driver, run or TestControl")
            self._scheduler = Optional(context._runtime.value().scheduler())
            self._owner = _running_poller(self._scheduler.value(), True)
            if not self._owner:
                abort("fp.effects: a descriptor wait ran off its pool's workers")
            var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=self._owner)
            self._shared = poller[].shared()
            self._registration = poller[].register(self._fd, self._interest, self._signal)
            if not self._registration:
                abort("fp.effects: the poller is closed")
        elif self._finish():
            var unit: NoneType = None
            return Step[NoneType, Self.E].ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))
        var wait = Wait.changed(self._signal, revision)
        wait._interruptible = not context._masked
        return Step[NoneType, Self.E].pending(wait^)


def await_readable[E: Movable & Deinitable](fd: RawFileDescriptor) -> IO[NoneType, E]:
    """Wait until a descriptor is readable, suspending the fiber in its thread's poller.

    The caller owns the descriptor and keeps it open and nonblocking until the
    IO completes. Hang-up and error conditions count as ready: the caller finds
    them by reading. Cancellation completes the IO canceled and removes the
    registration. Readiness is reported once; each wait registers again.

    Parameters:
        E: The IO's error type; the wait itself never fails.

    Args:
        fd: The descriptor; a negative one aborts.

    Returns:
        An IO producing unit once the descriptor is ready. Running it outside a
        Driver, run or TestControl, or failing to open the poller, aborts.
    """
    return IO[NoneType, E].lift(_AwaitDescriptor[E](fd, READ_INTEREST))


def await_writable[E: Movable & Deinitable](fd: RawFileDescriptor) -> IO[NoneType, E]:
    """Wait until a descriptor is writable, suspending the fiber in its thread's poller.

    The caller owns the descriptor and keeps it open and nonblocking until the
    IO completes. Hang-up and error conditions count as ready: the caller finds
    them by writing. Cancellation completes the IO canceled and removes the
    registration. Readiness is reported once; each wait registers again.

    Parameters:
        E: The IO's error type; the wait itself never fails.

    Args:
        fd: The descriptor; a negative one aborts.

    Returns:
        An IO producing unit once the descriptor is ready. Running it outside a
        Driver, run or TestControl, or failing to open the poller, aborts.
    """
    return IO[NoneType, E].lift(_AwaitDescriptor[E](fd, WRITE_INTEREST))
