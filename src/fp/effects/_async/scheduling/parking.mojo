"""The pool's parking protocol: counts of active and searching workers, and parked flags.

After Cats Effect's `WorkStealingThreadPool` (`state`, `transitionWorkerToSearching`,
`transitionWorkerFromSearching`, `transitionWorkerToParked*`, `doneSleeping`,
`notifyParked`) and `WorkerThread` (`notifyDoneSleeping`, `parkLoop`). This
module is the state machine only: the operating-system park and unpark belong
to the poller, so callers park and unpark however their profile does it and
report back through these methods.

State:

- One word packs the number of active (unparked) workers in its high 32 bits
  and the number of searching workers in its low 32 bits; all workers start
  active and none searching. Upstream packs two 16-bit counts.
- Each worker has a parked flag: UNPARKED, PARKED, INTERRUPTING, or
  NOT_STARTED. A notifier claims a PARKED worker by compare-exchange to
  INTERRUPTING, so exactly one notifier unparks it for one parking; it counts
  the worker active and searching (`doneSleeping`), unparks it, then stores
  UNPARKED.
- Lazy start. A pool may begin with only its first `started` workers running
  (the calling thread as worker 0, Runtime API item 6). The others begin
  NOT_STARTED, counted inactive like parked workers, and a notifier claims one
  exactly as it claims a parked worker; `notify_parked` reports that the
  claimed worker must be started rather than unparked (`_Notified.start`). A
  started thread begins active and searching, as an unparked one resumes.

Worker protocol (the caller's loop):

1. With no local or external work, ask `transition_to_searching`. It is granted
   only while fewer than half the workers search (exactly, by compare-exchange;
   upstream checks then increments, which can overshoot).
2. A searcher that finds work calls `transition_from_searching`; when it was the
   last searcher it should call `notify_parked` so another worker can help.
3. To park: `prepare_to_park`, then `transition_to_parked_when_searching` (a
   searcher) or `transition_to_parked` (a worker refused permission). When the
   former reports the last searcher, re-check every queue and call
   `notify_parked` if any has work. Then park.
4. After waking, `after_wake` tells whether a notifier woke it (it is counted
   active and searching), or the wake was spurious (park again). A worker that
   leaves its park for its own reason (a timer or descriptor event) calls
   `wake_self` instead.

Submitters publish work, then call `notify_parked`, which wakes a worker only
when none is searching and fewer than all are active.

Why no work is lost: a submitter publishes work, then executes a sequentially
consistent fence and reads the state word. A parking searcher changes the state
word with a sequentially consistent read-modify-write, executes a sequentially
consistent fence, and re-checks the queues. Either the submitter's read sees
the decrement, so it finds no searcher and a parked flag to claim (the flag is
stored before the decrement), or the parker's re-check sees the work. A worker
refused permission parks without re-checking because a searcher existed when
it was refused, and that searcher, or the last one after it, re-checks after
the refusal; a worker that stays active looks at the queues again before
parking.

Memory ordering of each atomic operation:

- Every read-modify-write of the state word is SEQUENTIAL, so all of them
  belong to one total order with the fences above.
- `notify_parked` executes `fence[SEQUENTIAL]` and then loads the state word
  with ACQUIRE. The fence orders the caller's publication of work before the
  load (the handshake above). The acquire pairs with the parking worker's
  read-modify-write (a release), so a notifier that sees the decrement also sees
  the PARKED flag stored before it.
- `transition_to_parked_when_searching` executes `fence[SEQUENTIAL]` after its
  read-modify-write, ordering it before the caller's re-check loads.
- `prepare_to_park` first waits, with ACQUIRE loads, while a notifier holds
  the flag INTERRUPTING (a thread started by a notifier can reach its first
  park before the notifier's `finish_unpark`), then stores PARKED with
  RELEASE; the following read-modify-write would order the store anyway, and
  the release keeps it from moving after it.
- A notifier reads flags RELAXED and claims with an ACQUIRE compare-exchange
  (RELAXED on failure), pairing with the RELEASE store of PARKED. Only one
  compare-exchange can succeed for one parking.
- `finish_unpark` stores UNPARKED with RELEASE after the notifier's count update
  and unpark; the worker's ACQUIRE load in `after_wake` or `wake_self` sees both.
- `wake_self` claims its own flag from PARKED to UNPARKED with an ACQUIRE
  compare-exchange; if a notifier holds INTERRUPTING it waits, with ACQUIRE
  loads, for UNPARKED and leaves the counting to the notifier.
- A worker waiting for a notifier's INTERRUPTING to end (`after_wake`,
  `wake_self`) spins `_UNPARK_SPINS` times and then yields between reads, so
  a notifier preempted between its claim and `finish_unpark` does not hold a
  core spinning.
- The searcher-bound compare-exchange is SEQUENTIAL on success and RELAXED on
  failure, which only reloads the counts.
- `active` and `searching` load RELAXED; they are hints for diagnostics and tests.

`transition_from_searching` reports the last searcher by its searching count.
Upstream compares the whole word with 1, which an active caller never matches.
"""
from std.atomic import Atomic, Ordering, fence
from std.memory.alloc import unsafe_alloc
from std.time import sleep
from .random import _Random

comptime _SEARCHING_ONE = UInt64(1)
comptime _ACTIVE_ONE = UInt64(1) << 32
comptime _SEARCHING_MASK = _ACTIVE_ONE - 1

comptime _UNPARKED = UInt8(0)
comptime _PARKED = UInt8(1)
comptime _INTERRUPTING = UInt8(2)
comptime _NOT_STARTED = UInt8(3)

comptime _UNPARK_SPINS = 64
"""Reads of an INTERRUPTING flag before a waiting worker starts yielding between reads."""


@fieldwise_init
struct _Notified(Copyable, TrivialRegisterPassable):
    """A worker a notifier claimed: unpark it, or start its thread; `worker` is -1 when none."""
    var worker: Int
    var start: Bool


@always_inline
def _pause(mut spins: Int):
    """Spin a little, then yield the processor, while another thread finishes a short step."""
    if spins < _UNPARK_SPINS:
        spins += 1
    else:
        sleep(0.0)


@always_inline
def _searching_of(state: UInt64) -> Int:
    return Int(state & _SEARCHING_MASK)


@always_inline
def _active_of(state: UInt64) -> Int:
    return Int(state >> 32)


struct _PaddedState(Movable):
    var value: Atomic[UInt64]
    var _padding: Array[Int, 7]

    def __init__(out self, value: UInt64):
        self.value = Atomic(value)
        self._padding = Array[Int, 7](fill=0)


struct _PaddedFlag(Movable):
    var value: Atomic[UInt8]
    var _padding: Array[Int, 7]

    def __init__(out self):
        self.value = Atomic(_UNPARKED)
        self._padding = Array[Int, 7](fill=0)


struct _Parking(Movable):
    """The shared parking state of a pool of `threads` workers; all methods may race."""
    var _threads: Int
    var _state: Pointer[_PaddedState, MutUntrackedOrigin]
    var _flags: Pointer[_PaddedFlag, MutUntrackedOrigin]

    def __init__(out self, threads: Int, started: Int = -1):
        """`threads` workers, of which the first `started` (all by default) run from the start."""
        self._threads = threads
        var running = threads if started < 0 else started
        self._state = unsafe_alloc[_PaddedState](1, alignment=64)
        self._state.unsafe_write(_PaddedState(UInt64(running) << 32))
        self._flags = unsafe_alloc[_PaddedFlag](threads, alignment=64)
        for i in range(threads):
            self._flags.unsafe_offset(i).unsafe_write(_PaddedFlag())
            if i >= running:
                self._flags[unsafe_offset=i].value.store[ordering=Ordering.RELAXED](_NOT_STARTED)

    def __deinit__(deinit self):
        self._state.unsafe_deinit_pointee()
        self._state.unsafe_free()
        for i in range(self._threads):
            self._flags.unsafe_offset(i).unsafe_deinit_pointee()
        self._flags.unsafe_free()

    @always_inline
    def threads(self) -> Int:
        return self._threads

    @always_inline
    def _word(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._state[].value

    @always_inline
    def _flag(self, worker: Int) -> ref[MutUntrackedOrigin] Atomic[UInt8]:
        return self._flags[unsafe_offset=worker].value

    def active(self) -> Int:
        """Unparked workers; a hint."""
        return _active_of(self._word().load[ordering=Ordering.RELAXED]())

    def searching(self) -> Int:
        """Searching workers; a hint."""
        return _searching_of(self._word().load[ordering=Ordering.RELAXED]())

    # Worker transitions.

    def transition_to_searching(self) -> Bool:
        """Become a searcher if fewer than half the workers search."""
        var state = self._word().load[ordering=Ordering.RELAXED]()
        while 2 * _searching_of(state) < self._threads:
            if self._word().compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](state, state + _SEARCHING_ONE):
                return True
        return False

    def transition_from_searching(self) -> Bool:
        """Stop searching after finding work; True when the caller should `notify_parked`."""
        var previous = self._word().fetch_sub[ordering=Ordering.SEQUENTIAL](_SEARCHING_ONE)
        return _searching_of(previous) == 1

    def prepare_to_park(self, worker: Int):
        """Publish `worker`'s intent to park; call before the parking transition.

        First waits, spinning then yielding, while a notifier still holds the
        flag INTERRUPTING. A thread that a notifier started (or `start`
        claimed) runs before its starter's `finish_unpark`, and could reach
        its first park in that gap: storing PARKED there would be overwritten
        by the starter's UNPARKED, leaving a parked worker that no notifier
        can claim and whose next wake `after_wake` takes as counted. The
        state word then loses one active and one searching count per such
        park, until the searching count underflows and every later notify
        sees a searcher and wakes no one (found by `wstp_stress`). Once the flag
        reads UNPARKED only this worker changes it, so the check and the
        store cannot be separated by another claim.
        """
        var spins = 0
        while self._flag(worker).load[ordering=Ordering.ACQUIRE]() == _INTERRUPTING:
            _pause(spins)
        self._flag(worker).store[ordering=Ordering.RELEASE](_PARKED)

    def transition_to_parked(self):
        """Park a worker that is not searching."""
        _ = self._word().fetch_sub[ordering=Ordering.SEQUENTIAL](_ACTIVE_ONE)

    def transition_to_parked_when_searching(self) -> Bool:
        """Park a searcher; True when it was the last, so the caller must re-check the queues."""
        var previous = self._word().fetch_sub[ordering=Ordering.SEQUENTIAL](_ACTIVE_ONE + _SEARCHING_ONE)
        fence[Ordering.SEQUENTIAL]()
        return _searching_of(previous) == 1

    def wake_self(self, worker: Int):
        """`worker` leaves its park for its own reason and counts itself unless a notifier did."""
        var spins = 0
        while True:
            var flag = self._flag(worker).load[ordering=Ordering.ACQUIRE]()
            if flag == _UNPARKED:
                return
            if flag == _INTERRUPTING:
                _pause(spins)
                continue
            if self._flag(worker).compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](flag, _UNPARKED):
                self._done_sleeping()
                return

    def after_wake(self, worker: Int) -> Bool:
        """After `worker`'s parker returns: True when a notifier woke it, False when spurious."""
        var spins = 0
        while True:
            var flag = self._flag(worker).load[ordering=Ordering.ACQUIRE]()
            if flag == _UNPARKED:
                return True
            if flag == _PARKED:
                return False
            # INTERRUPTING: the notifier is unparking this worker; wait for it to finish.
            _pause(spins)

    # Notification.

    def notify_parked(self, mut random: _Random) -> Int:
        """After publishing work: claim a parked worker to wake, or return -1.

        A claimed worker is already counted active and searching. The caller
        unparks it, then calls `finish_unpark` with the returned index. Never
        claims a worker that has not started; see `notify`.
        """
        return self._claim[False](random).worker

    def notify(self, mut random: _Random) -> _Notified:
        """`notify_parked` for a pool that starts workers lazily: a not-started worker may be claimed too.

        The caller starts a claimed worker's thread when `start` is set, and
        unparks it otherwise, then calls `finish_unpark` either way.
        """
        return self._claim[True](random)

    def _claim[lazy: Bool](self, mut random: _Random) -> _Notified:
        fence[Ordering.SEQUENTIAL]()
        var state = self._word().load[ordering=Ordering.ACQUIRE]()
        if _searching_of(state) != 0 or _active_of(state) >= self._threads:
            return _Notified(-1, False)
        var origin = random.below(self._threads)
        for i in range(self._threads):
            var worker = (origin + i) % self._threads
            var flag = self._flag(worker).load[ordering=Ordering.RELAXED]()
            var claimable = flag == _PARKED
            comptime if lazy:
                claimable = claimable or flag == _NOT_STARTED
            if claimable and self._flag(worker).compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](flag, _INTERRUPTING):
                self._done_sleeping()
                return _Notified(worker, flag == _NOT_STARTED)
        return _Notified(-1, False)

    def start(self, worker: Int) -> Bool:
        """Claim a not-started worker to start it now, counted active and searching; True when claimed.

        For a pool that starts every worker at once. The caller starts the
        thread, then calls `finish_unpark`.
        """
        var flag = _NOT_STARTED
        if self._flag(worker).compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](flag, _INTERRUPTING):
            self._done_sleeping()
            return True
        return False

    def wait_unparked(self, worker: Int):
        """Wait, spinning then yielding, while a notifier holds `worker` INTERRUPTING; ACQUIRE loads.

        After it returns, whatever the notifier did before `finish_unpark`,
        such as starting the worker's thread, is visible.
        """
        var spins = 0
        while self._flag(worker).load[ordering=Ordering.ACQUIRE]() == _INTERRUPTING:
            _pause(spins)

    def start_failed(self, worker: Int):
        """The claimed `worker`'s thread could not start: uncount it and mark it not started again.

        Instead of `finish_unpark`. The decrement is SEQUENTIAL, as every
        change of the state word; the flag is stored with RELEASE. A later
        notifier may claim the worker and try again.
        """
        _ = self._word().fetch_sub[ordering=Ordering.SEQUENTIAL](_ACTIVE_ONE + _SEARCHING_ONE)
        self._flag(worker).store[ordering=Ordering.RELEASE](_NOT_STARTED)

    def stop(self, worker: Int) -> Bool:
        """Claim a not-started worker so that it never starts; for shutdown. True when claimed."""
        var flag = _NOT_STARTED
        return self._flag(worker).compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](flag, _INTERRUPTING)

    def finish_unpark(self, worker: Int):
        """The notifier has unparked `worker`; let it proceed."""
        self._flag(worker).store[ordering=Ordering.RELEASE](_UNPARKED)

    @always_inline
    def _done_sleeping(self):
        _ = self._word().fetch_add[ordering=Ordering.SEQUENTIAL](_ACTIVE_ONE + _SEARCHING_ONE)
