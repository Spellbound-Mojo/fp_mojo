"""Scoped exclusive access to native shared storage, with no escaping references.

Only the native atomic gate is accessed before acquisition. The payload may be
borrowed mutably only through the move-only lease; its destructor releases the
gate on normal return and native error unwinding. Reentry or overlapping access
aborts instead of deadlocking or creating a second mutable payload reference.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort


@fieldwise_init
struct _ExclusiveCell[T: Movable & Deinitable](Movable):
    # Atomic itself is immovable on Mojo 1.1. Its static pointer operations
    # provide the native synchronization over this scalar storage.
    var gate: Int32
    var value: Self.T


@fieldwise_init
struct _ExclusiveLease[T: Movable & Deinitable, o: MutOrigin](Movable):
    var cell: Pointer[_ExclusiveCell[Self.T], Self.o]
    def value(mut self) -> ref[self] Self.T:
        # Narrow the allocation borrow to the guard: a client cannot keep a
        # payload reference across unlocking, even while the owner survives.
        return Pointer(to=self.cell[].value).unsafe_origin_cast[origin_of(self)]()[]
    def __deinit__(deinit self):
        Atomic[Int32].store(Pointer(to=self.cell[].gate), Int32(0))


def _exclusive[T: Movable & Deinitable, o: ImmOrigin](
    ref[o] owner: ArcPointer[_ExclusiveCell[T]]
) -> _ExclusiveLease[T, o.unsafe_mut_cast[True]()]:
    var expected = Int32(0)
    if not Atomic[Int32].compare_exchange(Pointer(to=owner[].gate), expected, Int32(1)):
        abort("fp.iteration: reentrant or concurrent branch access")
    return _ExclusiveLease(Pointer(to=owner[]))
