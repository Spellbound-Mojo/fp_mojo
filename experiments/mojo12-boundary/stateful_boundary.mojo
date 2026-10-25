"""Explicit owned state with native mutable-argument semantics."""
from fp.callables.native import _NativeMutOwnedRef
from fp.callables.products import _OptionalCell
from fp.data._result import Result, attempt as _capture_arguments

struct Stateful[S: Movable & Deinitable, A: Movable & Deinitable,
                R: Movable & Deinitable, E: Movable & Deinitable,
                F: Movable & Deinitable, raising: Bool](Movable):
    var _state: Self.S
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F, var state: Self.S):
        self._function = Optional(function^)
        self._state = state^
    def state(ref self) -> ref[self._state] Self.S:
        return self._state
    def into_state(deinit self) -> Self.S:
        return self._state^
    def run(mut self, var value: Self.A) -> Result[Self.R, Self.E]:
        comptime o = origin_of(self._function._value)
        var callback = _NativeMutOwnedRef[Self.S, Self.A, Self.R, Self.E, Self.F, Self.raising, o](Pointer(to=self._function.value()))
        return _capture_arguments(callback, self._state, value^)

struct Capture[E: Movable & Deinitable]:
    @staticmethod
    def stateful[S: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, //](function: def(mut S, var A) thin -> R, var state: S) -> Stateful[S, A, R, Never, type_of(function), False]:
        return Stateful[S, A, R, Never, type_of(function), False](function, state^)
    @staticmethod
    def stateful[S: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, //](function: def(mut S, var A) raises Self.E thin -> R, var state: S) -> Stateful[S, A, R, Self.E, type_of(function), True]:
        return Stateful[S, A, R, Self.E, type_of(function), True](function, state^)
    @staticmethod
    def stateful[S: Movable & Deinitable, A: Movable & Deinitable, //](function: def(mut S, var A) thin, var state: S) -> Stateful[S, A, type_of(None), Never, type_of(function), False]:
        return Stateful[S, A, type_of(None), Never, type_of(function), False](function, state^)
    @staticmethod
    def stateful[S: Movable & Deinitable, A: Movable & Deinitable, //](function: def(mut S, var A) raises Self.E thin, var state: S) -> Stateful[S, A, type_of(None), Self.E, type_of(function), True]:
        return Stateful[S, A, type_of(None), Self.E, type_of(function), True](function, state^)
