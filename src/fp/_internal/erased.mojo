"""Owned type erasure with construction-paired casts.

`_Erased` hides the concrete type of one owned value. Small trivially movable
values live inline; others occupy one native `OwnedPointer` allocation. Only a
function specialized by the type that created the box may cast it back: the
stored destroy function here, and operation functions that consumers specialize
in their own generic constructors. The raw address never leaves the private
erasure owners.

Erasure drops every origin the value embeds. Callers must erase only values
whose state is owned, or whose origins also appear in a type the consumer keeps;
Mojo 1.2 cannot check that precondition.
"""
from std.collections.array import Array
from std.memory import OwnedPointer
from std.sys.info import size_of, align_of
from std.traits.movable import IsTriviallyMovable
from std.traits.deinitable import IsTriviallyDeinitable

comptime _Address = MutOpaquePointer[MutUntrackedOrigin]
comptime _WORDS = 3

# A trivially movable value moves correctly with the box's own bitwise move.
comptime _Inline[T: AnyType] = IsTriviallyMovable[T] and size_of[T]() <= 8 * _WORDS and align_of[T]() <= 8


def _no_destroy(storage: _Address):
    pass


struct _Erased(Movable):
    """One owned value of a hidden type, destroyed exactly once.

    Inline values occupy the storage words; a heap value's address does.
    """
    var _storage: Array[UInt64, _WORDS]
    var _destroy: def(_Address) thin

    def __init__(out self):
        """An empty box that owns nothing."""
        self._storage = Array[UInt64, _WORDS](uninitialized=True)
        self._destroy = _no_destroy

    def __init__[T: Movable & Deinitable](out self, var value: T):
        self._storage = Array[UInt64, _WORDS](uninitialized=True)
        comptime if _Inline[T]:
            def destroy_inline(storage: _Address):
                comptime if not IsTriviallyDeinitable[T]:
                    storage.unsafe_bitcast[T]().unsafe_deinit_pointee()

            self._destroy = destroy_inline
            self._storage.unsafe_ptr().unsafe_bitcast[T]().unsafe_write(value^)
        else:
            def destroy_heap(storage: _Address):
                # Reconstruct the native owner: it runs T's destructor and frees.
                _ = OwnedPointer[T](unsafe_from_opaque_pointer=storage.unsafe_bitcast[_Address]()[])

            var owner = OwnedPointer(value^)
            self._destroy = destroy_heap
            self._storage.unsafe_ptr().unsafe_bitcast[_Address]().unsafe_write(owner^.unsafe_take_allocation().unsafe_leak().unsafe_bitcast[NoneType]())

    def __deinit__(deinit self):
        self._destroy(self._storage.unsafe_ptr().unsafe_bitcast[NoneType]().unsafe_origin_cast[MutUntrackedOrigin]())

    def take[T: Movable & Deinitable](deinit self) -> T:
        """Move the value out without destroying it.

        Only a function specialized by the type that created this box may call
        this. The typed API that builds the box fixes `T` at the same site.
        """
        comptime if _Inline[T]:
            return self._storage.unsafe_ptr().unsafe_bitcast[T]().unsafe_take_pointee()
        else:
            return OwnedPointer[T](unsafe_from_opaque_pointer=self._storage.unsafe_ptr().unsafe_bitcast[_Address]()[]).into_inner()

    def pointer[T: AnyType](mut self) -> Pointer[T, origin_of(self)]:
        """Lend the value with this owner's origin, under the same pairing rule.

        An untracked copy of the address would let ASAP destruction free the
        owner while an operation still uses it; this origin keeps it alive.
        """
        comptime if _Inline[T]:
            return self._storage.unsafe_ptr().unsafe_bitcast[T]().unsafe_origin_cast[origin_of(self)]()
        else:
            return self._storage.unsafe_ptr().unsafe_bitcast[_Address]()[].unsafe_bitcast[T]().unsafe_origin_cast[origin_of(self)]()
