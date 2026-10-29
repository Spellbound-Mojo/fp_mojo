"""Shared guarded storage, independent of effect contexts and wake metadata."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.time import sleep


@fieldwise_init
struct _Cell[T: Movable & Deinitable](Movable):
    var lock: Atomic[UInt8]
    var slot: Optional[Self.T]


@fieldwise_init
struct _Guard[T: Movable & Deinitable](Movable):
    var cell: ArcPointer[_Cell[Self.T]]
    def __deinit__(deinit self):
        self.cell[].lock.store(0)


def _try_lock[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> Optional[_Guard[T]]:
    var expected = UInt8(0)
    if cell[].lock.compare_exchange(expected, UInt8(1)):
        return Optional(_Guard(cell.copy()))
    return None


def _lock_metadata[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> _Guard[T]:
    """Only short internal metadata sections; no user code or held polls."""
    while True:
        var guard = _try_lock(cell)
        if guard:
            return guard.take()
        sleep(0.0)
