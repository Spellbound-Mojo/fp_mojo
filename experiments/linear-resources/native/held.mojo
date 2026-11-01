"""An internal holder that is Deinitable itself and checks at run time that its linear value was taken."""
from std.os import abort
from std.builtin.rebind import rebind_var, downcast


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        print("close", self.id)


struct Held[T: Movable](Movable):
    """Deinitable whatever T is; destroys a Deinitable value, aborts on a linear one.

    A plain field rather than Optional storage: Optional made the library's
    composed resource scopes take minutes to compile."""
    var _value: Self.T

    def __init__(out self, var value: Self.T):
        self._value = value^

    def __getitem__(ref self) -> ref[self._value] Self.T:
        return self._value

    def take(deinit self) -> Self.T:
        return self._value^

    def __deinit__(deinit self):
        comptime if conforms_to(Self.T, Deinitable):
            _ = rebind_var[downcast[Self.T, Movable & Deinitable]](self._value^)
        else:
            abort("linear resource value abandoned inside the scope")


def main():
    var held = Held(Handle(1))
    print("borrowed id", held[].id)
    var h = held^.take()
    h^.close()
    # An ordinary payload works the same way, and may simply be dropped.
    var plain = Held(String("x"))
    _ = plain^
    print("plain dropped")
