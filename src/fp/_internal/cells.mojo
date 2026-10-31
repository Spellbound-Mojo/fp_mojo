"""Shared guarded storage, independent of effect contexts and wake metadata.

One implementation acquires and releases a cell's lock word (`_acquire_lock`,
`_try_acquire_lock`, `_release_lock`). Two guards use it:

- `_Guard`, from `_try_lock` and `_lock_metadata`, holds a copy of the cell's
  `ArcPointer`, so it may outlive the caller's reference. Its orderings are
  sequentially consistent and `_lock_metadata` yields after every failed
  attempt, as before the borrowed guard was added.
- `_CellGuard`, from `_lock_cell`, borrows the cell, so locking costs no
  reference counting. It acquires with ACQUIRE and releases with RELEASE, which
  is all mutual exclusion needs: the releasing store publishes the critical
  section to the next acquiring compare-exchange. It spins on a relaxed load
  for a bounded number of attempts before yielding with `sleep(0.0)`.
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


def _acquire_lock[spins: Int, success: Ordering = Ordering.SEQUENTIAL, failure: Ordering = Ordering.SEQUENTIAL](mut lock: Atomic[UInt8]):
    """Acquire `lock`, retrying up to `spins` times between yields; zero yields after every failure."""
    var attempts = 0
    while not _try_acquire_lock[success, failure](lock):
        if attempts < spins:
            # Retry only once the word reads free, so spinning stays in the cache.
            attempts += 1
            while attempts < spins and lock.load[ordering=Ordering.RELAXED]() != 0:
                attempts += 1
        else:
            attempts = 0
            sleep(0.0)


@always_inline
def _release_lock[ordering: Ordering = Ordering.SEQUENTIAL](mut lock: Atomic[UInt8]):
    lock.store[ordering=ordering](0)


@fieldwise_init
struct _Guard[T: Movable & Deinitable](Movable):
    var cell: ArcPointer[_Cell[Self.T]]
    def __deinit__(deinit self):
        _release_lock(self.cell[].lock)


def _try_lock[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> Optional[_Guard[T]]:
    if _try_acquire_lock(cell[].lock):
        return Optional(_Guard(cell.copy()))
    return None


def _lock_metadata[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> _Guard[T]:
    """Only short internal metadata sections; no user code or held polls."""
    _acquire_lock[0](cell[].lock)
    return _Guard(cell.copy())


struct _CellGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    """A held lock on a borrowed cell, released when the guard is destroyed."""
    var cell: Pointer[_Cell[Self.T], Self.origin]

    def __init__(out self, cell: Pointer[_Cell[Self.T], Self.origin]):
        self.cell = cell

    def __deinit__(deinit self):
        _release_lock[Ordering.RELEASE](self.cell[].lock)


def _lock_cell[T: Movable & Deinitable, origin: MutOrigin, //](ref[origin] cell: _Cell[T]) -> _CellGuard[T, origin]:
    """Lock a borrowed cell for a short internal section: no user code or held polls."""
    # A failed attempt orders nothing; only the winning compare-exchange acquires.
    _acquire_lock[_CELL_SPINS, Ordering.ACQUIRE, Ordering.RELAXED](cell.lock)
    return _CellGuard[T, origin](Pointer(to=cell))
