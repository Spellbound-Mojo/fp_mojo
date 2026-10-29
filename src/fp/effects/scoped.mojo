"""Origin-preserving factories for IO that borrows an enclosing scope."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import OnceThunk, BorrowCallContract
from fp.callables._receiver import _OnceBorrowAvailable, _borrow_once_as
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _ErrorCompatible
from .protocols import ReaderAction
from .outcomes import Outcome, EffectFailure, _capture
from ._io_core import IOContext, IOContract, _run_io, _settle
from fp.data import Result, Err


trait ScopedIO(Movable, Deinitable):
    """Build an IO action that may borrow its input until that action finishes.

    Action takes the fresh input origin. Value and Error do not: neither the
    completed result nor a failure can escape that borrow. Captured independent
    origins remain part of the concrete factory. Use scoped_io for ordinary
    borrowing callbacks whose returned action has an input-independent type.
    """
    comptime Input: AnyType
    """The borrowed input type."""
    comptime Value: Movable & Deinitable
    """The completed action's result, independent of the input origin."""
    comptime Error: Movable & Deinitable
    """The IO error family, independent of the input origin."""
    comptime BuildError: Movable & Deinitable = Never
    """Native construction error, either Error or Never."""
    comptime Action[o: ImmOrigin]: ReaderAction
    """An IO action retaining the input origin until it completes."""

    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) raises Self.BuildError -> Self.Action[o]:
        """Construct the action; the runner keeps value alive through execution.

        Parameters:
            o: The borrowed input's exact origin.

        Args:
            value: The input borrowed by the constructed action.

        Returns:
            An IO action yielding Value in the selected Error family.

        Raises:
            BuildError if constructing the action fails.
        """
        ...


comptime _ScopedInputCompatible[T: AnyType, E: Movable & Deinitable, F: ScopedIO] = (
    F.Input == T and F.Error == E and _ErrorCompatible[E, F.BuildError]
)


@fieldwise_init
struct _ScopedBuild[F: ScopedIO, o: ImmOrigin](OnceThunk):
    var function: Self.F
    var input: Pointer[Self.F.Input, Self.o]
    comptime Out = Self.F.Action[Self.o]
    comptime Error = Self.F.BuildError
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return self.function^.build(self.input[])


def _run_scoped[F: ScopedIO, o: ImmOrigin, c: ImmOrigin, E: Movable & Deinitable](var function: F, ref[o] value: F.Input, ref[c] context: IOContext[E]
) -> Outcome[F.Value, E] where F.Error == E:
    # The enclosing context owns E. An explicit parameter preserves that witness
    # across generic resource/factory projections without casting each caller.
    comptime assert _ErrorCompatible[E, F.BuildError]
    comptime assert IOContract[F.Action[o]].Compatible
    comptime assert F.Action[o].Value == F.Value and IOContract[F.Action[o]].Error == E, "ScopedIO action must preserve the declared value and error"
    if context.canceled():
        return None
    var built = _capture[E](_ScopedBuild(function^, Pointer(to=value)))
    if built.is_err():
        return _settle(Optional(Result[F.Value, EffectFailure[E]](Err(built^._take_err()))), context)
    return rebind_var[Outcome[F.Value, E]](_run_io(built^._take_ok(), rebind[IOContext[IOContract[F.Action[o]].Error]](context)))


@fieldwise_init
struct _ScopedFactory[F: BorrowCallContract & Movable & Deinitable, P: ReaderAction = downcast[F.Result, ReaderAction]](ScopedIO):
    var function: Self.F
    # Native admission can retain its already inferred ReaderAction witness.
    # Re-projecting it through F.Result loses generic IO error equalities in 1.2.
    comptime Program = Self.P
    comptime Input = Self.F.Payload
    comptime Value = Self.Program.Value
    comptime Error = IOContract[Self.Program].Error
    comptime BuildError = Self.F.Failure
    comptime Action[o: ImmOrigin] = Self.Program
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) raises Self.BuildError -> Self.Action[o]:
        comptime assert Self.F.Result == Self.Program
        return rebind_var[Self.Program](_borrow_once_as[Self.BuildError](value, self.function^))


comptime _ScopedFactoryCompatible[F: BorrowCallContract & Movable & Deinitable] = (
    _OnceBorrowAvailable[F] and IOContract[downcast[F.Result, ReaderAction]].Compatible
    and _ErrorCompatible[IOContract[downcast[F.Result, ReaderAction]].Error, F.Failure]
) if conforms_to(F.Result, ReaderAction) else False


def scoped_io[F: BorrowCallContract & Movable & Deinitable](var function: F) -> _ScopedFactory[F] where _ScopedFactoryCompatible[F]:
    """Adapt a borrowing factory returning IO to ScopedIO without executing it.

    The returned program has a fixed type and cannot borrow the fresh input.
    Implement ScopedIO directly when the action needs that input's origin.

    Parameters:
        F: The borrowing factory, preserving its exact captures and errors.

    Args:
        function: The factory, consumed without invocation.

    Returns:
        A scoped factory with the returned IO action's value and error types.
    """
    return _ScopedFactory(function^)


def scoped_io[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](var function: F) -> _ScopedFactory[_NativeBorrow[P, V, Never, F, False]] where _ScopedFactoryCompatible[_NativeBorrow[P, V, Never, F, False]]:
    """Adapt a native borrowing factory returning an IO program."""
    return scoped_io(_NativeBorrow[P, V, Never, F, False](function^))


def scoped_io[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](var function: F) -> _ScopedFactory[_NativeBorrow[P, V, X, F, True]] where _ScopedFactoryCompatible[_NativeBorrow[P, V, X, F, True]]:
    """Adapt a native factory with a compatible exact construction error."""
    return scoped_io(_NativeBorrow[P, V, X, F, True](function^))


# --- native scoped IO pointers (generated) ---
def scoped_io[P: AnyType, R: ReaderAction, q: ImmOrigin, //](ref[q] function: def(P) thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R] where _ScopedFactoryCompatible[_NativeBorrow[P, R, Never, type_of(function), False]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R](_NativeBorrow[P, R, Never, type_of(function), False](function))


def scoped_io[P: AnyType, R: ReaderAction & RegisterPassable, //](function: def(P) thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R] where not conforms_to(P, TrivialRegisterPassable) and _ScopedFactoryCompatible[_NativeBorrow[P, R, Never, type_of(function), False]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R](_NativeBorrow[P, R, Never, type_of(function), False](function))


def scoped_io[P: TrivialRegisterPassable, R: ReaderAction, //](function: def(P) thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R] where not conforms_to(R, RegisterPassable) and _ScopedFactoryCompatible[_NativeBorrow[P, R, Never, type_of(function), False]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R](_NativeBorrow[P, R, Never, type_of(function), False](function))


def scoped_io[P: TrivialRegisterPassable, R: ReaderAction & RegisterPassable, //](function: def(P) thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R] where _ScopedFactoryCompatible[_NativeBorrow[P, R, Never, type_of(function), False]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, Never, type_of(function), False], R](_NativeBorrow[P, R, Never, type_of(function), False](function))


def scoped_io[P: AnyType, R: ReaderAction, E: Movable & Deinitable, q: ImmOrigin, //](ref[q] function: def(P) raises E thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R] where _ScopedFactoryCompatible[_NativeBorrow[P, R, E, type_of(function), True]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R](_NativeBorrow[P, R, E, type_of(function), True](function))


def scoped_io[P: AnyType, R: ReaderAction & RegisterPassable, E: Movable & Deinitable, //](function: def(P) raises E thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R] where not conforms_to(P, TrivialRegisterPassable) and _ScopedFactoryCompatible[_NativeBorrow[P, R, E, type_of(function), True]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R](_NativeBorrow[P, R, E, type_of(function), True](function))


def scoped_io[P: TrivialRegisterPassable, R: ReaderAction, E: Movable & Deinitable, //](function: def(P) raises E thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R] where not conforms_to(R, RegisterPassable) and _ScopedFactoryCompatible[_NativeBorrow[P, R, E, type_of(function), True]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R](_NativeBorrow[P, R, E, type_of(function), True](function))


def scoped_io[P: TrivialRegisterPassable, R: ReaderAction & RegisterPassable, E: Movable & Deinitable, //](function: def(P) raises E thin -> R) -> _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R] where _ScopedFactoryCompatible[_NativeBorrow[P, R, E, type_of(function), True]]:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return _ScopedFactory[_NativeBorrow[P, R, E, type_of(function), True], R](_NativeBorrow[P, R, E, type_of(function), True](function))


# --- end native scoped IO pointers ---
