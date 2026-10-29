"""Synchronous IO endpoints executed once inside the inherited async context."""
from fp.effects._io_core import IOContext, IOContract, DelayContract, _run_io, delay as _delay
from fp.effects.protocols import ReaderAction
from fp.callables.protocols import ThunkContract
from fp.callables.native import _NativeThunk, _Thunk, _RaisingThunk
from fp._internal.errors import _ErrorCompatible
from .kernel import Machine, Step


struct EvalIO[P: ReaderAction](Machine):
    comptime Value = Self.P.Value
    comptime Error = IOContract[Self.P].Error
    var _program: Optional[Self.P]

    def __init__(out self, var program: Self.P):
        comptime assert IOContract[Self.P].Compatible
        self._program = Optional(program^)

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert IOContract[Self.P].Compatible
        # The canonical IO runner captures native errors and settles cancellation
        # in this context. A top-level run_io would create a different root.
        return .ready(_run_io(self._program.take(), context))


def eval_io[P: ReaderAction](var program: P) -> EvalIO[P] where IOContract[P].Compatible:
    return EvalIO(program^)


def delay[F: ThunkContract & Movable & Deinitable, //, E: Movable & Deinitable](var function: F
) -> EvalIO[DelayContract[F, E].Out] where DelayContract[F, E].Compatible:
    return eval_io(_delay[E](function^))


def delay[T: Movable & Deinitable, //, E: Movable & Deinitable, F: _Thunk[T]](var function: F
) -> EvalIO[DelayContract[_NativeThunk[T, Never, F, False], E].Out]:
    return delay[E](_NativeThunk[T, Never, F, False](function^))


def delay[T: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingThunk[T, X]](var function: F
) -> EvalIO[DelayContract[_NativeThunk[T, X, F, True], E].Out] where _ErrorCompatible[E, X]:
    return delay[E](_NativeThunk[T, X, F, True](function^))
