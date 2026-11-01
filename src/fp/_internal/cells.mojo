"""Shared guarded storage, independent of effect contexts and wake metadata.

One implementation acquires and releases a cell's lock word (`_acquire_lock`,
`_try_acquire_lock`, `_release_lock`). Two guards use it:

- `_Guard`, from `_try_lock` and `_lock_metadata`, holds a copy of the cell's
  `ArcPointer`, so it may outlive the caller's reference. Its orderings are
  sequentially consistent and `_lock_metadata` yields after every failed
  attempt, as before the borrowed guard was added.
- `_CellGuard`, from `_lock_cell`, borrows the cell, so locking costs no
  reference counting. Its guarded value is reached through `value()`, whose
  reference borrows the guard, so the lock cannot be released early. It acquires with ACQUIRE and releases with RELEASE, which
  is all mutual exclusion needs: the releasing store publishes the critical
  section to the next acquiring compare-exchange. It spins on a relaxed load
  for a bounded number of attempts before yielding with `sleep(0.0)`.

`_lock_until_canceled` is the third client: the coordination owners' `_lock`,
which spins and yields like the borrowed guard and asks its waiter (the
calling context) between yields whether cancellation stops the wait. No lock in
this module sleeps for a fixed interval.

Memory ordering of each atomic operation on a cell's lock word:

- Acquiring is a compare-exchange from 0 to 1. `_Guard` (`_try_lock`,
  `_lock_metadata`) and `_lock_until_canceled` use SEQUENTIAL on success and
  failure; `_CellGuard` (`_lock_cell`) uses ACQUIRE on success and RELAXED on
  failure, since a failed attempt orders nothing. The success ordering's
  acquire half pairs with the previous holder's release, so the guarded
  value and everything written before the release are visible.
- While waiting, `_acquire_lock` re-reads the word RELAXED before it retries,
  so spinning stays in the cache; only the compare-exchange acquires.
- Releasing is a store of 0: SEQUENTIAL for `_Guard`, RELEASE for
  `_CellGuard`. Either publishes the critical section to the next acquirer.
- The sequentially consistent `_Guard` orderings are stronger than mutual
  exclusion needs. They are kept because some callers pair a section with
  other SEQUENTIAL operations (for example the scheduler's ready queue with
  its `polling` word, `waking.mojo`), and relaxing them would need an audit of
  each such pairing first.

A guard must stay alive through its last access to the guarded value. Both
guards make every access a use of the guard: `_Guard` through the
`ArcPointer` it owns, `_CellGuard` through `value()`. A value computed inside
the section and used after it, such as a length stored into another atomic,
needs `_ = guard^` after that use, as `_ExternalQueue.push` does.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.time import sleep

comptime _CELL_SPINS = 256
"""Attempts a borrowed guard makes before yielding the processor.

With four threads contending for four external-queue stripes, 64 spins cost
as much as yielding at once, and 256 or more matched spinning without yielding
(probes/wstp_cost.mojo).
"""


@fieldwise_init
struct _Cell[T: Movable & Deinitable](Movable):
    var lock: Atomic[UInt8]
    var slot: Optional[Self.T]


@always_inline
def _try_acquire_lock[success: Ordering = Ordering.SEQUENTIAL, failure: Ordering = Ordering.SEQUENTIAL](mut lock: Atomic[UInt8]) -> Bool:
    var expected = UInt8(0)
    return lock.compare_exchange[success_ordering=success, failure_ordering=failure](expected, UInt8(1))


trait _LockWaiter:
    """Whether a waiter for a held lock should stop waiting, checked between yields."""
    def canceled(self) -> Bool:
        ...


struct _Patient(_LockWaiter, Defaultable):
    """A waiter that never stops: the lock is acquired."""
    def __init__(out self):
        pass

    @always_inline
    def canceled(self) -> Bool:
        return False


def _acquire_lock[spins: Int, success: Ordering = Ordering.SEQUENTIAL, failure: Ordering = Ordering.SEQUENTIAL, W: _LockWaiter = _Patient](mut lock: Atomic[UInt8], waiter: W = _Patient()) -> Bool:
    """Acquire `lock`, retrying up to `spins` times between yields; zero yields after every failure.

    Before each yield the waiter is asked whether to stop; a stopped wait
    returns false without the lock. The default waiter never stops.
    """
    var attempts = 0
    while not _try_acquire_lock[success, failure](lock):
        if attempts < spins:
            # Retry only once the word reads free, so spinning stays in the cache.
            attempts += 1
            while attempts < spins and lock.load[ordering=Ordering.RELAXED]() != 0:
                attempts += 1
        else:
            if waiter.canceled():
                return False
            attempts = 0
            sleep(0.0)
    return True


@always_inline
def _release_lock[ordering: Ordering = Ordering.SEQUENTIAL](mut lock: Atomic[UInt8]):
    lock.store[ordering=ordering](0)


@fieldwise_init
struct _Guard[T: Movable & Deinitable](Movable):
    # `guard.cell[]` derives from this field, an `ArcPointer` the guard owns,
    # so every use of the reference is a use of the guard: the lock is held
    # until the last one (see `_CellGuard` for the borrowed case).
    var cell: ArcPointer[_Cell[Self.T]]
    def __deinit__(deinit self):
        _release_lock(self.cell[].lock)


def _try_lock[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> Optional[_Guard[T]]:
    if _try_acquire_lock(cell[].lock):
        return Optional(_Guard(cell.copy()))
    return None


def _lock_metadata[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> _Guard[T]:
    """Only short internal metadata sections; no user code or held polls."""
    _ = _acquire_lock[0](cell[].lock)
    return _Guard(cell.copy())


def _lock_until_canceled[T: Movable & Deinitable, W: _LockWaiter](cell: ArcPointer[_Cell[T]], waiter: W) -> Optional[_Guard[T]]:
    """Lock a cell for its waiter, spinning and then yielding; none once the waiter is canceled.

    A waiter canceled before the first attempt never acquires. Orderings are
    sequentially consistent, as for every `_Guard`.
    """
    if waiter.canceled():
        return None
    if _acquire_lock[_CELL_SPINS](cell[].lock, waiter):
        return Optional(_Guard(cell.copy()))
    return None


struct _CellGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    """A held lock on a borrowed cell, released when the guard is destroyed.

    Mojo destroys a value after its last use. A reference derived from a raw
    pointer the guard holds does not count as a use of the guard, so code that
    wrote through such a reference could run after the guard had already
    released the lock. The pointer is therefore private, and the guarded value
    is reachable only through `value`, whose result borrows the guard itself:
    every use of the reference keeps the guard, and the lock, alive.
    """
    var _cell: Pointer[_Cell[Self.T], Self.origin]

    def __init__(out self, cell: Pointer[_Cell[Self.T], Self.origin]):
        self._cell = cell

    def __deinit__(deinit self):
        _release_lock[Ordering.RELEASE](self._cell[].lock)

    def value(mut self) -> ref[self] Self.T:
        """The guarded value, for as long as this guard lives."""
        return Pointer(to=self._cell[].slot.value()).unsafe_origin_cast[origin_of(self)]()[]


def _lock_cell[T: Movable & Deinitable, origin: MutOrigin, //](ref[origin] cell: _Cell[T]) -> _CellGuard[T, origin]:
    """Lock a borrowed cell for a short internal section: no user code or held polls."""
    # A failed attempt orders nothing; only the winning compare-exchange acquires.
    _ = _acquire_lock[_CELL_SPINS, Ordering.ACQUIRE, Ordering.RELAXED](cell.lock)
    return _CellGuard[T, origin](Pointer(to=cell))
