"""The polling system: an owner thread's park, after Cats Effect's `PollingSystem`.

One POSIX implementation on `poll()` and a self-pipe. Cats Effect's
`PollingSystem` has `poll(poller, nanos)`, `needsPoll(poller)` and
`interrupt(thread, poller)`; Scala Native's interruptible wait is the same
self-pipe around `poll`. Here:

- `_Poller.poll(timeout)` waits on the registered descriptors and the
  self-pipe, indefinitely or up to a timeout, and reports ready registrations,
  an interrupt, expiry, or closing (`_PollResult`).
- `_Interrupter.interrupt()` (or `_Poller.interrupt()`), safe from any thread,
  makes the current or next `poll` return. Repeated interrupts coalesce into
  one byte in the pipe and one wake.
- `_Poller.register(fd, interest, signal)` adds read and/or write interest and
  returns a generation-checked `_Registration`. Readiness is reported once: the
  poll that sees it records the events, stops watching the descriptor, and
  notifies the `Signal`, so a waiter suspends with `Wait.changed(signal,
  revision)`. `deregister` removes the registration when its waiter completes
  or is canceled; a stale handle is a no-op.
- `needs_poll()` reports armed registrations: an owner without any may park
  more cheaply, and one with any must park here. `has_registrations()` also
  counts reported registrations not yet removed.
- `close()`, from any thread, wakes a poll in progress and releases the pipe as
  soon as no poll or interrupt is using it. A closed poller rejects new
  registrations, and the owner's next `poll` (or the poller's destruction)
  notifies the registrations still armed, which then report `closed()`.

Ownership. `poll`, `register`, `deregister`, `readiness` and the counts belong
to the poller's owner thread: one poller per root, and one per work-stealing
worker, as in Cats Effect, where each `WorkerThread` owns its poller. Only
`interrupt` and `close` cross threads, through `_Interrupter` copies that share
the wake state, never the `_Poller` itself, so no thread borrows the owner's
struct; and `_release_registration`, below. The caller owns its descriptors
and keeps each open and nonblocking until its registration is removed; the
poller owns only its pipe.

Releases from other threads. A work-stealing fiber may finish its
descriptor wait on another worker, which must not touch the owner's table.
Each registration's state is therefore an atomic word, `generation << 3 |
state`, in chunks that never move (the timer heap's `_StableChunks`), in an allocation
apart from the poller (`_RegistrationWords`) with a padded `released` count:

- The owner stores (generation, ARMED) RELEASE when it registers, and claims
  ARMED to FIRED (a poll) or ARMED to SHUT (closing) with RELAXED
  compare-exchanges. A failed claim means a release won: the registration is
  removed, or left to the sweep, and its signal is not notified.
- `_release_registration`, from any thread, loads the word ACQUIRE and, while
  its generation matches, sets the released bit with an ACQUIRE_RELEASE
  compare-exchange, then increments `released` RELEASE. It interrupts the
  owner when the registration was still armed, so that the owner stops
  watching a descriptor the caller may now close (Linux keeps a polled file
  open until `poll` returns). It returns whether the registration had fired
  or closed, as `readiness(...).pending()` would have reported false.
- At the top of every poll the owner loads `released` ACQUIRE; once it
  exceeds the releases it accounted for, it sweeps released words. It frees
  an entry by compare-exchanging its word to the next generation and FREE
  (ACQUIRE), which sees a release that raced it; a later release carries the
  old generation and fails. A recycled word starts at its new generation.

The poller outlives every release: on a pool, descriptor waits finish or are
dropped in task runs before their root completes, and the pool destroys its
pollers last.

A thread that registers no descriptors, such as a blocking-pool worker, uses
only `poll(timeout)` and `interrupt()`.

Timeouts. `poll()` counts whole milliseconds. A wait of at least 1 ms polls
for the whole milliseconds left, rounded down, and repeats against
`std.time.monotonic()`, so it never returns before its deadline. The final part
under 1 ms is waited with `std.time.sleep` between two nonblocking polls, which
can delay an interrupt or a descriptor's readiness by under 1 ms. `poll`
restarts after `EINTR` with the time remaining.

The handshake that loses no wake. An interrupter publishes its work (an atomic
write, or a write under a lock the owner's re-check takes), then calls
`interrupt`. The owner calls `poll`, which ends by draining the pipe when it was
readable and then clearing the flag; after `poll` returns, the owner re-checks
its work before polling again. The pending flag is one word:

- `interrupt` executes `fence[SEQUENTIAL]`, then loads the flag RELAXED and
  returns at once when it is set (read before writing: a coalesced interrupt
  writes nothing). Otherwise it claims the flag from 0 to 1 with a SEQUENTIAL
  compare-exchange (RELAXED on failure) and writes one byte to the pipe.
- The owner, after draining, loads the flag RELAXED, clears a set flag with a
  SEQUENTIAL compare-exchange from 1 to 0 (only the owner writes 0, so it
  succeeds), then executes `fence[SEQUENTIAL]` before returning to the
  owner's re-check.

Either the interrupter's flag load comes after the owner's clear in the single
total order of sequentially consistent operations, so it sees 0, claims the
flag and writes a byte, which the next poll finds because the owner drains
only before clearing; or the clear comes after the interrupter's fence, and the
owner's fenced re-check sees the work published before that fence. A byte
written by an interrupter whose claim preceded the clear may arrive after the
drain; it costs one spurious wake, never a lost one. `interrupted` therefore
means "re-check", as with any park.

Lifetime of the pipe. A second padded word counts users of the pipe, in units
of 4, with bit 0 for closed and bit 1 for released. `poll` and `interrupt`
enter with an ACQUIRE `fetch_add` and back out if the poller is closed; they
leave with a RELEASE `fetch_sub`. `close` enters, sets the closed bit with an
ACQUIRE_RELEASE compare-exchange loop, writes one byte to wake a poll in
progress, and leaves. Whoever leaves last after closing releases the pipe: a
compare-exchange from exactly "closed, no users" to "closed and released"
(ACQUIRE on success, RELAXED on failure) has one winner, and its acquire reads
the end of the release sequence of every leave, so all writes and drains
happen before the descriptors close. The winner destroys the pipe in place,
closing each end exactly once; the shared state frees the rest with its last
`ArcPointer`. `is_closed` loads ACQUIRE.
"""
from std.atomic import Atomic, Ordering, fence
from std.ffi import c_int
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import monotonic, sleep
from fp._internal.os import OSError, POLLIN, POLLOUT, Pipe, PollFd, poll as _poll_descriptors
from fp._internal.time import Duration
from fp._internal.waking import Signal, _next_generation, _Scheduler, _WakeHook
from .scheduling.parking import _PaddedState
from .scheduling.timer_heap import _StableChunks

comptime READ_INTEREST: Int16 = POLLIN
"""Interest in readability, or a hang-up that makes a read return at once."""
comptime WRITE_INTEREST: Int16 = POLLOUT
"""Interest in writability."""

comptime _MILLISECOND = 1_000_000

# The users word: bit 0 closed, bit 1 released, and the user count above.
comptime _CLOSED = UInt64(1)
comptime _RELEASED = UInt64(2)
comptime _USER = UInt64(4)

# Registration states, the low bits of each registration's word (`generation << 3 | state`).
comptime _FREE = UInt8(0)
comptime _ARMED = UInt8(1)
comptime _FIRED = UInt8(2)
comptime _SHUT = UInt8(3)
comptime _STATE_BITS = UInt64(3)
# Set by another thread that released the registration (`_release_registration`).
comptime _RELEASED_BIT = UInt64(4)
comptime _LOW_BITS = UInt64(7)
comptime _GENERATION_LIMIT = UInt64(1) << 61


struct _WakeState(Movable):
    """The pending flag, the pipe and its users, shared with every interrupter.

    Every method takes immutable `self`, and each word lives in its own
    cache-line allocation behind a pointer.
    """

    var _flag: Pointer[_PaddedState, MutUntrackedOrigin]
    var _users: Pointer[_PaddedState, MutUntrackedOrigin]
    var _pipe: Pointer[Pipe, MutUntrackedOrigin]
    var _read_fd: c_int

    def __init__(out self) raises OSError:
        var pipe = Pipe.open_self_pipe()
        self._read_fd = pipe.read_end.fd
        self._pipe = unsafe_alloc[Pipe](1)
        self._pipe.unsafe_write(pipe^)
        self._flag = unsafe_alloc[_PaddedState](1, alignment=64)
        self._flag.unsafe_write(_PaddedState(0))
        self._users = unsafe_alloc[_PaddedState](1, alignment=64)
        self._users.unsafe_write(_PaddedState(0))

    def __deinit__(deinit self):
        # The last owner: no poll or interrupt can run. The poller always closes
        # before it is destroyed, so the pipe is normally released already.
        if (self._users[].value.load[ordering=Ordering.ACQUIRE]() & _RELEASED) == 0:
            self._pipe.unsafe_deinit_pointee()
        self._pipe.unsafe_free()
        self._flag.unsafe_deinit_pointee()
        self._flag.unsafe_free()
        self._users.unsafe_deinit_pointee()
        self._users.unsafe_free()

    @always_inline
    def _flag_word(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._flag[].value

    @always_inline
    def _users_word(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._users[].value

    def _enter(self) -> Bool:
        """Become a user of the pipe; False, with nothing held, once closed."""
        var previous = self._users_word().fetch_add[ordering=Ordering.ACQUIRE](_USER)
        if (previous & _CLOSED) != 0:
            self._leave()
            return False
        return True

    def _leave(self):
        """Stop using the pipe; the last user after closing releases it."""
        var previous = self._users_word().fetch_sub[ordering=Ordering.RELEASE](_USER)
        if previous == _CLOSED | _USER:
            var expected = _CLOSED
            if self._users_word().compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](expected, _CLOSED | _RELEASED):
                self._pipe.unsafe_deinit_pointee()

    def _write_wake(self):
        # A full pipe already holds a wake. Any other error means the protocol
        # let a descriptor close while in use, which must not continue.
        try:
            _ = self._pipe[].wake()
        except error:
            abort(String("fp.effects._async.polling: wake failed: ", error))

    def interrupt(self):
        """Make the owner's current or next poll return; safe from any thread."""
        fence[Ordering.SEQUENTIAL]()
        if self._flag_word().load[ordering=Ordering.RELAXED]() != 0:
            return
        var expected = UInt64(0)
        if not self._flag_word().compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](expected, 1):
            return
        if not self._enter():
            return
        self._write_wake()
        self._leave()

    def close(self) -> Bool:
        """Close and wake a poll in progress; True for the call that closed it."""
        if not self._enter():
            return False
        var state = self._users_word().load[ordering=Ordering.RELAXED]()
        while (state & _CLOSED) == 0:
            if self._users_word().compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.RELAXED](state, state | _CLOSED):
                self._write_wake()
                self._leave()
                return True
        self._leave()
        return False

    def is_closed(self) -> Bool:
        """Report whether any thread has closed the poller."""
        return (self._users_word().load[ordering=Ordering.ACQUIRE]() & _CLOSED) != 0

    def _take_interrupt(self) -> Bool:
        """Clear a pending interrupt after draining; True when one was set."""
        var pending = self._flag_word().load[ordering=Ordering.RELAXED]() != 0
        if pending:
            var expected = UInt64(1)
            _ = self._flag_word().compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](expected, 0)
        fence[Ordering.SEQUENTIAL]()
        return pending

    def _drain(self) raises OSError -> Int:
        return self._pipe[].drain()


@fieldwise_init
struct _Interrupter(Copyable):
    """A handle that wakes or closes a poller from any thread.

    Copies share the poller's wake state and may outlive the poller: an
    interrupt or close after closing does nothing.
    """

    var _wake: ArcPointer[_WakeState]

    def interrupt(self):
        """Make the owner's current or next poll return, coalescing repeats."""
        self._wake[].interrupt()

    def close(self) -> Bool:
        """Close the poller and wake a poll in progress.

        Returns:
            True for the call that closed it, False when already closed.
        """
        return self._wake[].close()

    def is_closed(self) -> Bool:
        """Report whether the poller is closed.

        Returns:
            True once any thread has closed it.
        """
        return self._wake[].is_closed()


@fieldwise_init
struct _Registration(Copyable, TrivialRegisterPassable):
    """A generation-checked handle to one registration; stale once removed."""

    var index: Int
    var generation: UInt64


struct _Readiness(Copyable):
    """What a registration has observed: pending, ready with events, closed, or stale."""

    var _state: UInt8
    var events: PollFd
    """The descriptor, its interest and the events poll reported, once ready."""

    def __init__(out self, state: UInt8, events: PollFd):
        self._state = state
        self.events = events

    def pending(self) -> Bool:
        """Report a live registration that has seen no readiness yet."""
        return self._state == _ARMED

    def ready(self) -> Bool:
        """Report that a poll observed events; see `events` for which."""
        return self._state == _FIRED

    def closed(self) -> Bool:
        """Report that the poller closed before the descriptor became ready."""
        return self._state == _SHUT

    def stale(self) -> Bool:
        """Report a handle whose registration was already removed."""
        return self._state == _FREE


@fieldwise_init
struct _PollResult(Copyable, Writable):
    """What one poll observed. Every field can be set at once."""

    var ready: Int
    """Registrations this poll found ready; their signals were notified."""
    var interrupted: Bool
    """An interrupt was pending or a wake byte arrived; the owner re-checks."""
    var expired: Bool
    """The timeout elapsed with nothing ready."""
    var closed: Bool
    """The poller is closed; outstanding registrations were notified."""
    var wake_bytes: Int
    """Bytes drained from the self-pipe; coalesced interrupts write one."""

    def __init__(out self):
        self.ready = 0
        self.interrupted = False
        self.expired = False
        self.closed = False
        self.wake_bytes = 0


@fieldwise_init
struct _Entry(Copyable):
    var fd: c_int
    var interest: Int16
    var revents: Int16
    var signal: Optional[Signal]


@always_inline
def _word(generation: UInt64, state: UInt8) -> UInt64:
    return (generation << 3) | UInt64(state)


@always_inline
def _state_of(word: UInt64) -> UInt8:
    return UInt8(word & _STATE_BITS)


struct _RegistrationWords(Movable):
    """What other threads touch: each registration's state word, the release count, the owner's wake state.

    In its own allocation, reached through an untracked pointer and never
    through the `_Poller`. Only the owner grows `words`, whose chunks never
    move (`_StableChunks`); another thread addresses only the word of a
    registration it was handed. See `_release_registration`.
    """

    var words: _StableChunks[Atomic[UInt64]]
    var released: Pointer[_PaddedState, MutUntrackedOrigin]
    var wake: Int

    def __init__(out self, wake: Int):
        self.words = _StableChunks[Atomic[UInt64]]()
        self.released = unsafe_alloc[_PaddedState](1, alignment=64)
        self.released.unsafe_write(_PaddedState(0))
        self.wake = wake

    def __deinit__(deinit self):
        self.released.unsafe_deinit_pointee()
        self.released.unsafe_free()

    @always_inline
    def at(self, index: Int) -> Pointer[Atomic[UInt64], MutUntrackedOrigin]:
        return self.words.ptr(index)


struct _Poller(Movable):
    """A `poll()` and self-pipe poller, used by its owner thread only.

    Other threads reach it through `interrupter()` copies, and release a
    registration through `_release_registration`. The destructor closes it,
    notifies armed registrations, and releases the pipe once no interrupt is
    writing to it.
    """

    var _wake: ArcPointer[_WakeState]
    var _entries: List[_Entry]
    var _shared: Pointer[_RegistrationWords, MutUntrackedOrigin]
    var _free: List[Int]
    var _armed: Int
    var _live: Int
    var _accounted: UInt64
    """Releases from other threads that the owner has removed."""
    var _descriptors: List[PollFd]
    """The pipe's read end, then each armed registration's descriptor."""
    var _slots: List[Int]
    """The entry of `_descriptors[i + 1]`."""
    var _dirty: Bool
    var _retired: Bool

    def __init__(out self) raises OSError:
        """Open the self-pipe.

        Raises:
            OSError: From pipe2, pipe or fcntl.
        """
        self._wake = ArcPointer(_WakeState())
        self._entries = List[_Entry]()
        self._shared = unsafe_alloc[_RegistrationWords](1)
        self._shared.unsafe_write(_RegistrationWords(Int(self._wake.ptr())))
        self._free = List[Int]()
        self._armed = 0
        self._live = 0
        self._accounted = 0
        self._descriptors = List[PollFd]()
        self._descriptors.append(PollFd(self._wake[]._read_fd, POLLIN))
        self._slots = List[Int]()
        self._dirty = False
        self._retired = False

    def __deinit__(deinit self):
        _ = self._wake[].close()
        _retire(self._entries, self._shared, self._armed)
        self._shared.unsafe_deinit_pointee()
        self._shared.unsafe_free()
        # Keep the shared state alive until after the close above.
        _ = self._wake^

    def interrupter(self) -> _Interrupter:
        """Share the wake state with another thread.

        Returns:
            A handle that interrupts or closes this poller from any thread.
        """
        return _Interrupter(self._wake.copy())

    def interrupt(self):
        """Interrupt from the owner thread, as an `_Interrupter` would."""
        self._wake[].interrupt()

    def wake_hook(self) -> _WakeHook:
        """This poller's interrupt as a `_WakeHook`, for code below this module.

        The hook holds no reference: its user stops firing it before the
        poller is destroyed (the root's scheduler closes first; a `Signal`
        subscription is dropped first).

        Returns:
            A hook whose `fire` interrupts this poller from any thread.
        """
        return _WakeHook(Int(self._wake.ptr()), _interrupt_at)

    def shared(self) -> Int:
        """The address another thread passes to `_release_registration`; lives as long as this poller.

        Returns:
            The address of this poller's registration words.
        """
        return Int(self._shared)

    def close(mut self):
        """Close, wake a poll in progress, and notify armed registrations."""
        _ = self._wake[].close()
        self._retire()

    def is_closed(self) -> Bool:
        """Report whether any thread has closed the poller.

        Returns:
            True once closed.
        """
        return self._wake[].is_closed()

    def needs_poll(self) -> Bool:
        """Report armed registrations, which only a poll here can observe.

        Returns:
            True when the owner must park in this poller rather than more cheaply.
        """
        return self._armed > 0

    def has_registrations(self) -> Bool:
        """Report registrations not yet removed, armed or already reported.

        Returns:
            True while any registration is live.
        """
        return self._live > 0

    def _pipe_descriptor(self) -> c_int:
        """The self-pipe's read end, for tests that check its release."""
        return self._wake[]._read_fd

    def register(mut self, fd: c_int, interest: Int16, signal: Signal) -> Optional[_Registration]:
        """Watch a descriptor until it is ready, then notify the signal once.

        The caller keeps the descriptor open and nonblocking until it removes
        the registration. Read the signal's revision before registering and
        wait with `Wait.changed(signal, revision)`; poll reports to `readiness`.

        Args:
            fd: An open descriptor the caller owns.
            interest: `READ_INTEREST`, `WRITE_INTEREST`, or both.
            signal: The signal to notify on readiness or closing.

        Returns:
            The registration, or None when the poller is closed.
        """
        if fd < 0 or interest == 0 or (interest & ~(READ_INTEREST | WRITE_INTEREST)) != 0:
            abort("fp.effects._async.polling: register needs a descriptor and read or write interest")
        if self._wake[].is_closed():
            self._retire()
            return None
        var entry = _Entry(fd, interest, 0, Optional(signal.copy()))
        var index: Int
        if len(self._free):
            index = self._free.pop()
            self._entries[index] = entry^
        else:
            index = len(self._entries)
            self._entries.append(entry^)
            if index == self._shared[].words.capacity():
                var end = self._shared[].words.grow()
                for i in range(index, end):
                    self._shared[].at(i).unsafe_write(Atomic(_word(1, _FREE)))
        var word = self._shared[].at(index)
        var generation = word[].load[ordering=Ordering.RELAXED]() >> 3
        word[].store[ordering=Ordering.RELEASE](_word(generation, _ARMED))
        self._armed += 1
        self._live += 1
        self._dirty = True
        return _Registration(index, generation)

    def _valid(self, handle: _Registration) -> Bool:
        if handle.index < 0 or handle.index >= len(self._entries):
            return False
        var word = self._shared[].at(handle.index)[].load[ordering=Ordering.RELAXED]()
        return word >> 3 == handle.generation and _state_of(word) != _FREE

    def deregister(mut self, handle: _Registration) -> Bool:
        """Remove a registration when its waiter completes or is canceled.

        Args:
            handle: The registration to remove.

        Returns:
            True when it was live; False for a stale handle, which changes nothing.
        """
        if not self._valid(handle):
            return False
        self._remove(handle.index)
        return True

    def _remove(mut self, index: Int):
        """Free a live entry, taking its word from whatever state another thread left it in."""
        var word = self._shared[].at(index)
        var previous = word[].load[ordering=Ordering.ACQUIRE]()
        var generation = _next_generation(previous >> 3)
        if generation >= _GENERATION_LIMIT:
            abort("fp.effects._async.polling: registration generation exhausted")
        # Only a release can change the word meanwhile, and only once: the
        # compare-exchange sees it, and a later release carries the old
        # generation and fails.
        while not word[].compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.ACQUIRE](previous, _word(generation, _FREE)):
            pass
        if previous & _RELEASED_BIT:
            self._accounted += 1
        if _state_of(previous) == _ARMED:
            self._armed -= 1
            self._dirty = True
        self._entries[index].signal = None
        self._live -= 1
        self._free.append(index)

    def _sweep(mut self):
        """Remove the registrations other threads released, once any were counted."""
        if self._shared[].released[].value.load[ordering=Ordering.ACQUIRE]() <= self._accounted:
            return
        for i in range(len(self._entries)):
            var word = self._shared[].at(i)[].load[ordering=Ordering.ACQUIRE]()
            if word & _RELEASED_BIT and _state_of(word) != _FREE:
                self._remove(i)

    def readiness(self, handle: _Registration) -> _Readiness:
        """Report what a registration has observed.

        Args:
            handle: The registration.

        Returns:
            Pending, ready with its events, closed, or stale.
        """
        if not self._valid(handle):
            return _Readiness(_FREE, PollFd(-1, 0))
        ref entry = self._entries[handle.index]
        var events = PollFd(entry.fd, entry.interest)
        events.revents = entry.revents
        return _Readiness(_state_of(self._shared[].at(handle.index)[].load[ordering=Ordering.RELAXED]()), events)

    def poll(mut self, timeout: Optional[Duration]) raises OSError -> _PollResult:
        """Wait for readiness, an interrupt, closing, or the timeout.

        After it returns, the owner re-checks its work before polling again;
        that order is what makes an interrupt published before the re-check
        impossible to lose.

        Args:
            timeout: None waits indefinitely; zero checks without waiting.

        Returns:
            What the poll observed. A closed poller returns at once.

        Raises:
            OSError: From poll or from draining the pipe.
        """
        var ready = List[Signal]()
        var result = self.poll_deferred(timeout, ready)
        for signal in ready:
            signal.notify()
        return result^

    def poll_deferred(mut self, timeout: Optional[Duration], mut ready: List[Signal]) raises OSError -> _PollResult:
        """Poll as `poll` does, but leave the ready registrations' signals to the caller.

        The root's driver notifies them itself, while it marks the root as
        polling, so readiness found by a park neither interrupts this poller
        again nor reaches the host notifier. Signals of registrations retired
        by closing are still notified here.

        Args:
            timeout: None waits indefinitely; zero checks without waiting.
            ready: Receives the signals of the registrations found ready.

        Returns:
            What the poll observed.

        Raises:
            OSError: From poll or from draining the pipe.
        """
        var result = _PollResult()
        self._sweep()
        if not self._wake[]._enter():
            self._retire()
            result.closed = True
            return result^
        var failure = Optional[OSError]()
        try:
            self._rebuild()
            result.expired = self._wait(timeout)
            if self._descriptors[0].ready():
                result.wake_bytes = self._wake[]._drain()
        except error:
            failure = error^
        result.interrupted = self._wake[]._take_interrupt() or result.wake_bytes > 0
        self._wake[]._leave()
        if failure:
            raise failure.value().copy()
        result.ready = self._fire(ready)
        if result.ready > 0 or result.interrupted:
            result.expired = False
        if self._wake[].is_closed():
            self._retire()
            result.closed = True
        return result^

    def _rebuild(mut self):
        if not self._dirty:
            return
        self._dirty = False
        while len(self._descriptors) > 1:
            _ = self._descriptors.pop()
        self._slots.clear()
        for i in range(len(self._entries)):
            if self._shared[].at(i)[].load[ordering=Ordering.RELAXED]() & _LOW_BITS == UInt64(_ARMED):
                self._descriptors.append(PollFd(self._entries[i].fd, self._entries[i].interest))
                self._slots.append(i)

    def _wait(mut self, timeout: Optional[Duration]) raises OSError -> Bool:
        """Poll until something is ready or the timeout expires; True on expiry."""
        if not timeout:
            _ = _poll_descriptors(self._descriptors, -1)
            return False
        var deadline = Int(monotonic()) + timeout.value().to_nanoseconds()
        while True:
            var remaining = deadline - Int(monotonic())
            if remaining >= _MILLISECOND:
                # Rounded down, so the wait never ends before the deadline.
                if _poll_descriptors(self._descriptors, remaining // _MILLISECOND) > 0:
                    return False
                continue
            if _poll_descriptors(self._descriptors, 0) > 0:
                return False
            if remaining <= 0:
                return True
            # Under 1 ms: poll() cannot wait this long, so sleep, then check
            # once more. An interrupt or readiness meanwhile waits for the sleep.
            sleep(Float64(remaining) / 1e9)

    def _fire(mut self, mut signals: List[Signal]) -> Int:
        """Record ready registrations, stop watching them, and collect their signals.

        The caller notifies the signals after the table is consistent, since a
        wake hook may run then. A registration another thread released
        meanwhile is removed instead, and its signal is not notified.
        """
        var count = 0
        for i in range(1, len(self._descriptors)):
            if self._descriptors[i].revents == 0:
                continue
            var revents = self._descriptors[i].revents
            self._descriptors[i].revents = 0
            var index = self._slots[i - 1]
            var word = self._shared[].at(index)
            var armed = word[].load[ordering=Ordering.RELAXED]()
            if _state_of(armed) != _ARMED:
                continue
            if armed & _RELEASED_BIT or not word[].compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](armed, _word(armed >> 3, _FIRED)):
                # Released by another thread before or during this claim.
                self._remove(index)
                continue
            ref entry = self._entries[index]
            entry.revents = revents
            self._armed -= 1
            self._dirty = True
            signals.append(entry.signal.value().copy())
            count += 1
        return count

    def _retire(mut self):
        if self._retired:
            return
        self._retired = True
        self._dirty = True
        _retire(self._entries, self._shared, self._armed)


def _retire(mut entries: List[_Entry], shared: Pointer[_RegistrationWords, MutUntrackedOrigin], mut armed: Int):
    """Mark armed registrations closed and notify their signals, once.

    A registration another thread released meanwhile keeps its released word
    and is not notified; the owner's sweep or destruction removes it.
    """
    var signals = List[Signal]()
    for i in range(len(entries)):
        var word = shared[].at(i)
        var current = word[].load[ordering=Ordering.RELAXED]()
        if current & _LOW_BITS != UInt64(_ARMED):
            continue
        if word[].compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](current, _word(current >> 3, _SHUT)):
            signals.append(entries[i].signal.value().copy())
    armed = 0
    for signal in signals:
        signal.notify()


def _release_registration(shared: Int, handle: _Registration) -> Bool:
    """Release a registration from a thread other than its poller's owner; True when readiness was observed.

    `shared` is the poller's `shared()` address, and the poller outlives the
    call. Marks the registration's word released and counts it; the owner
    removes it at its next poll (`_sweep`). A registration still armed also
    interrupts the owner, so that it stops watching a descriptor its caller
    may now close. Returns whether the registration had fired or seen the
    poller close, as `readiness(...).pending()` would have reported false.
    """
    var words = Pointer[_RegistrationWords, MutUntrackedOrigin](unsafe_from_address=shared)
    var word = words[].at(handle.index)
    var current = word[].load[ordering=Ordering.ACQUIRE]()
    while current >> 3 == handle.generation and not (current & _RELEASED_BIT) and _state_of(current) != _FREE:
        if word[].compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.ACQUIRE](current, current | _RELEASED_BIT):
            _ = words[].released[].value.fetch_add[ordering=Ordering.RELEASE](1)
            if _state_of(current) == _ARMED:
                _interrupt_at(words[].wake)
                return False
            return True
    # Already removed or released: nothing is left to observe.
    return True


def _interrupt_at(target: Int):
    """`_WakeHook`'s call: interrupt the `_WakeState` at an address."""
    Pointer[_WakeState, MutUntrackedOrigin](unsafe_from_address=target)[].interrupt()


# ===------------------------------------------------------------------=== #
# The root's poller
# ===------------------------------------------------------------------=== #


# A root's poller lives in a heap allocation whose address is the scheduler's
# `poller` word: 0 until the root first parks or awaits a descriptor, so a root
# that never does opens no pipe. Only the thread driving the root creates,
# uses and destroys it (RELAXED loads and stores; each work-stealing worker owns
# its own). Creating it installs its interrupt as the scheduler's wake hook
# (`_Scheduler.install_wake`), after which a wake delivered while no poll runs
# interrupts it. The root's finish destroys it after `_Scheduler.close`, so no
# waker can still be firing the hook.


def _root_poller(scheduler: ArcPointer[_Scheduler]) raises OSError -> Pointer[_Poller, MutUntrackedOrigin]:
    """The root's poller, created on first use on the driving thread.

    A caller that is about to park re-checks the ready queue after this
    returns: that is the driver's half of the lost-wake handshake
    (`_Scheduler.notify_host`).

    Raises:
        OSError: The self-pipe could not be opened.
    """
    var word = scheduler[].poller_word()
    var address = word[].load[ordering=Ordering.RELAXED]()
    if address == 0:
        var poller = unsafe_alloc[_Poller](1)
        try:
            poller.unsafe_write(_Poller())
        except error:
            poller.unsafe_free()
            raise error^
        address = Int(poller)
        word[].store[ordering=Ordering.RELAXED](address)
        scheduler[].install_wake(poller[].wake_hook())
    return Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)


def _existing_root_poller(scheduler: ArcPointer[_Scheduler]) -> Optional[Pointer[_Poller, MutUntrackedOrigin]]:
    """The root's poller if it was created; never creates one."""
    var address = scheduler[].poller_word()[].load[ordering=Ordering.RELAXED]()
    if address == 0:
        return None
    return Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)


def _finish_root_poller(scheduler: ArcPointer[_Scheduler]):
    """Close and destroy the root's poller; after `_Scheduler.close`, so no waker fires its hook."""
    var word = scheduler[].poller_word()
    var address = word[].load[ordering=Ordering.RELAXED]()
    if address == 0:
        return
    word[].store[ordering=Ordering.RELAXED](0)
    var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)
    poller.unsafe_deinit_pointee()
    poller.unsafe_free()
