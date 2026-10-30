"""Owned type erasure with construction-paired casts over one native allocation.

`_Erased` hides the concrete type of one owned value. Only a function specialized
by the type that created the allocation may cast it back: the stored destroy
function here, and operation functions that consumers specialize in their own
generic constructors. The raw address never leaves the private erasure owners.

Erasure drops every origin the value embeds. Callers must erase only values
whose state is owned, or whose origins also appear in a type the consumer keeps;
Mojo 1.2 cannot check that precondition.
"""
from std.memory import OwnedPointer

comptime _Address = MutOpaquePointer[MutUntrackedOrigin]


struct _Erased(Movable):
    """One owned heap value of a hidden type, destroyed exactly once."""
    var _address: _Address
    var _destroy: def(_Address) thin

    def __init__[T: Movable & Deinitable](out self, var value: T):
        def destroy(address: _Address):
            # Reconstruct the native owner: it runs T's destructor and frees.
            _ = OwnedPointer[T](unsafe_from_opaque_pointer=address)

        var owner = OwnedPointer(value^)
        self._address = owner^.unsafe_take_allocation().unsafe_leak().unsafe_bitcast[NoneType]()
        self._destroy = destroy

    def __deinit__(deinit self):
        self._destroy(self._address)

    def view(mut self) -> MutOpaquePointer[origin_of(self)]:
        """Lend the address with this owner's origin.

        An untracked copy of the address would let ASAP destruction free the
        owner while an operation still uses it; this origin keeps it alive.
        """
        return self._address.unsafe_origin_cast[origin_of(self)]()
