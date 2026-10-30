"""A stable machine carrier over the canonical owned-erasure owner."""
from std.builtin.rebind import rebind_var
from fp._internal.erased import _Erased
from fp.effects import IOContext
from .kernel import Machine, Step


comptime _Poll[T: Movable & Deinitable, E: Movable & Deinitable] = def(mut _Erased, IOContext[E]) thin -> Step[T, E]


struct _ErasedMachine[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    """Poll a machine of hidden type through one carrier type per result and error.

    The value and error types, with their origins, remain in the carrier. The
    machine's own captured origins are erased; admit only owned machine state.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    var _program: _Erased
    var _poll: _Poll[Self.T, Self.E]

    def __init__[P: Machine](out self, var program: P) where P.Value == Self.T and P.Error == Self.E:
        def poll(mut program: _Erased, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
            comptime assert P.Value == Self.T and P.Error == Self.E
            return rebind_var[Step[Self.T, Self.E]](
                program.pointer[P]()[].poll(rebind[IOContext[P.Error]](context)))

        self._program = _Erased(program^)
        self._poll = poll

    def __init__(out self, var program: _Erased, poll: _Poll[Self.T, Self.E]):
        """Reassemble a carrier from parts an erasing constructor paired."""
        self._program = program^
        self._poll = poll

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        return self._poll(self._program, context)
