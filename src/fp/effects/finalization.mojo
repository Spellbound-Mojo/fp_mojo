"""Outcome-aware finalization and lexically restored cancellation regions."""
from std.builtin.rebind import downcast, rebind_var
from std.memory import ArcPointer
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Err
from .protocols import ReaderAction
from .outcomes import Outcome, EffectFailure, ExitCase, _ExitState, _capture, _finish
from ._io_core import IO, IOContext, IOContract, _run_io, _settle
from .scoped import _ScopedInputCompatible, ScopedIO, _run_scoped

comptime _FinalizerCompatible[P: ReaderAction, Q: ReaderAction] = IOContract[P].Compatible and IOContract[Q].Compatible and IOContract[P].Error == IOContract[Q].Error

comptime _CaseFinalizerCompatible[P: ReaderAction, F: ScopedIO] = GuaranteeCaseContract[P, F].Compatible


def _finalize[P: ReaderAction, F: ScopedIO, o: ImmOrigin, only_cancel: Bool = False](var program: P, var finalizer: F, ref[o] env: IOContext[IOContract[P].Error]
) -> IOContract[P].Out where _CaseFinalizerCompatible[P, F]:
    var completed = _run_io(program^, env)
    return _finalize_outcome[only_cancel=only_cancel](completed^, finalizer^, env)


def _finalize_outcome[T: Movable & Deinitable, E: Movable & Deinitable, F: ScopedIO, o: ImmOrigin, only_cancel: Bool = False](var completed: Outcome[T, E], var finalizer: F, ref[o] env: IOContext[E]
) -> Outcome[T, E] where F.Error == E and F.Input == ExitCase[E]:
    var state = _ExitState(_settle(completed^, env))
    if only_cancel and not state.exit.is_canceled():
        return _settle(state^.outcome(), env)
    var masked = env._mask()
    var cleanup = _run_scoped(finalizer^, rebind[F.Input](state.exit), masked)
    return _settle(_finish(state^.outcome(), cleanup^), env)


@fieldwise_init
struct _ConstantFinalizer[P: ReaderAction, T: AnyType = ExitCase[IOContract[P].Error]](ScopedIO):
    var program: Self.P
    comptime Input = Self.T
    comptime Value = Self.P.Value
    comptime Error = IOContract[Self.P].Error
    comptime Action[o: ImmOrigin] = Self.P
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return self.program^


@fieldwise_init
struct _IOGuarantee[P: ReaderAction, Q: ReaderAction, only_cancel: Bool = False](ReaderAction):
    var program: Self.P
    var finalizer: Self.Q
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert _FinalizerCompatible[Self.P, Self.Q]
        return _finalize[only_cancel=Self.only_cancel](self.program^, _ConstantFinalizer[Self.Q, ExitCase[Self.E]](self.finalizer^), env)


def guarantee[P: ReaderAction, Q: ReaderAction](var program: P, var finalizer: Q
) -> _IOGuarantee[P, Q] where _FinalizerCompatible[P, Q]:
    """Finalize an entered IO body exactly once, with cancellation masked.

    Finalization runs after success, failure or cancellation. All errors remain
    ordered body first, then finalizer. Unopened recipes run neither operation.

    Parameters:
        P: The body program type.
        Q: A finalizer in the same selected IO error family.

    Args:
        program: The body, consumed into the new recipe.
        finalizer: The deferred finalizer; its success value is discarded.

    Returns:
        A program with the body's success type and combined failure outcomes.
    """
    return _IOGuarantee(program^, finalizer^)


def on_cancel[P: ReaderAction, Q: ReaderAction](var program: P, var finalizer: Q
) -> _IOGuarantee[P, Q, True] where _FinalizerCompatible[P, Q]:
    """Run masked cleanup only when the entered body observes cancellation.

    Also runs when the body both fails and observes cancellation. Ordinary
    errors and successes skip cleanup. Errors raised by cleanup are retained.

    Parameters:
        P: The body program type.
        Q: A cleanup program in the same error family.

    Args:
        program: The protected program, consumed.
        finalizer: The cancellation cleanup, consumed and deferred.

    Returns:
        The body outcome combined with any cancellation-cleanup errors.
    """
    return _IOGuarantee[P, Q, True](program^, finalizer^)


@fieldwise_init
struct _IOGuaranteeCase[P: ReaderAction, F: ScopedIO](ReaderAction):
    var program: Self.P
    var finalizer: Self.F
    comptime E = IOContract[Self.P].Error
    comptime Family = Self.P.Family
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert _CaseFinalizerCompatible[Self.P, Self.F]
        return _finalize(self.program^, self.finalizer^, env)


struct GuaranteeCaseContract[P: ReaderAction, F: ScopedIO]:
    """Admission and result metadata for outcome-aware IO finalization.

    The body owns the family, success type and error channel. The finalizer
    borrows its exit case and returns IO with that same error type. Forward
    Compatible in generic wrappers and name Out without private recipe types.
    Construction runs neither the body nor the cleanup factory.

    Parameters:
        P: The complete body recipe, including its captured origins.
        F: The scoped cleanup factory, including independent captured origins.
    """
    comptime Family = Self.P.Family
    """The body's unchanged family, for fluent continuation."""
    comptime NativeError = IOContract[Self.P].Error
    """The body's native error type, retained inside the execution outcome."""
    comptime Input = ExitCase[Self.NativeError]
    """The exit case borrowed while constructing and running cleanup."""
    comptime Compatible = IOContract[Self.P].Compatible and _ScopedInputCompatible[Self.Input, Self.NativeError, Self.F]
    """Body membership, exact cleanup input/error and compatible construction error."""
    comptime Out = _IOGuaranteeCase[Self.P, Self.F]
    """The unopened recipe with the body's value and finalization behavior."""
    comptime Error = Never
    """Construction itself cannot raise; deferred cleanup errors enter the outcome."""
    comptime Outcome = IOContract[Self.P].Out
    """The exact host result after execution, including failures or cancellation."""


def guarantee_case[P: ReaderAction, F: ScopedIO](var program: P, var finalizer: F
) -> _IOGuaranteeCase[P, F] where _CaseFinalizerCompatible[P, F]:
    """Finalize with an effect that borrows the body's exact exit case.

    Construction and execution of the finalizer are masked and captured. The
    effect may borrow the exit case while running, but its result and errors
    cannot retain that borrow. Neither body errors nor successes are copied.

    Parameters:
        P: The body program type.
        F: A ScopedIO factory over ExitCase in the body's error family.

    Args:
        program: The body, consumed and deferred.
        finalizer: The scoped factory; use scoped_io for ordinary callbacks.

    Returns:
        A program retaining the body result and all body/cleanup errors.
    """
    return _IOGuaranteeCase(program^, finalizer^)


@fieldwise_init
struct Poll[E: Movable & Deinitable](Copyable):
    """Restore the cancellation state preceding one uncancelable_with region.

    A poll only restores its own currently active region. Nested masks and
    finalizers remain protected; a poll retained beyond its region is inert.
    Restoring an outer mask leaves cancellation masked. The marker is owned,
    so retaining this value never leaves a pointer into a finished stack frame.

    Parameters:
        E: The selected IO error family.
    """
    var _previous: IOContext[Self.E]
    var _region: ArcPointer[Int]
    comptime Applied[P: ReaderAction] = _IOPolled[P, Self.E]
    """The concrete recipe returned by apply, for generic factories."""

    def apply[P: ReaderAction](self, var program: P) -> _IOPolled[P, Self.E] where IOContract[P].Compatible and IOContract[P].Error == Self.E:
        """Run a program with this region's previous cancellation state.

        Parameters:
            P: A compatible IO program in this poll's error family.

        Args:
            program: The program, consumed without execution now.

        Returns:
            A deferred restoration around the given program.
        """
        return _IOPolled(program^, self.copy())


@fieldwise_init
struct _IOPolled[P: ReaderAction, E: Movable & Deinitable](ReaderAction):
    var program: Self.P
    var poll: Poll[Self.E]
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert IOContract[Self.P].Compatible and IOContract[Self.P].Error == Self.E
        if env._region and env._region.value().ptr() == self.poll._region.ptr():
            return rebind_var[Self.Out[o]](_run_io(self.program^, rebind[IOContext[IOContract[Self.P].Error]](self.poll._previous)))
        return rebind_var[Self.Out[o]](_run_io(self.program^, rebind[IOContext[IOContract[Self.P].Error]](env)))


@fieldwise_init
struct _IOMaskBody[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](ReaderAction):
    var function: Self.F
    comptime Program = downcast[Self.F.Out, ReaderAction]
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.Program.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return _settle(_masked_factory[Self.F, Self.E](self.function^, env), env)


def _masked_factory[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin](var function: F, ref[o] env: IOContext[E]
) -> Outcome[downcast[F.Out, ReaderAction].Value, E]:
    """Run a Poll factory under a mask; the caller owns the unmask checkpoint."""
    comptime assert IOContract[downcast[F.Out, ReaderAction]].Compatible and IOContract[downcast[F.Out, ReaderAction]].Error == E
    comptime assert F.Arg == Poll[E] and _ErrorCompatible[E, F.Error]
    var masked = env._mask()
    var poll = Poll(env.copy(), masked._region.value().copy())
    var built = _capture[E](_OwnedUnary(function^, rebind_var[F.Arg](poll^)))
    if built.is_err():
        return Optional(Result[downcast[F.Out, ReaderAction].Value, EffectFailure[E]](Err(built^._take_err())))
    return rebind_var[Outcome[downcast[F.Out, ReaderAction].Value, E]](_run_io(rebind_var[downcast[F.Out, ReaderAction]](built^._take_ok()), rebind[IOContext[IOContract[downcast[F.Out, ReaderAction]].Error]](masked)))


def uncancelable_with[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var function: F
) -> _IOMaskBody[F, E] where F.Arg == Poll[E] and _OnceUnaryAvailable[F] and _ErrorCompatible[E, F.Error] and conforms_to(F.Out, ReaderAction) and IOContract[downcast[F.Out, ReaderAction]].Compatible and IOContract[downcast[F.Out, ReaderAction]].Error == E:
    """Build a masked region with controlled restoration through Poll.

    The factory receives a poll at execution, inside the new mask. Applying it
    restores the enclosing state only for that subprogram. Construction errors
    are captured; pending cancellation is observed on leaving the outer mask.

    Parameters:
        F: A consuming factory from Poll[E] to IO[E].
        E: The exact IO error family, selected explicitly.

    Args:
        function: The deferred factory, consumed once.

    Returns:
        A masked IO recipe with the factory's resulting value type.
    """
    return _IOMaskBody[F, E](function^)


def uncancelable_with[P: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[P, V]](var function: F
) -> _IOMaskBody[NativeUnary[P, V, Never, F, False], E] where P == Poll[E] and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == E:
    """Adapt a non-raising native Poll factory to the shared masking runner."""
    return uncancelable_with[E](NativeUnary[P, V, Never, F, False](function^))


def uncancelable_with[P: Movable & Deinitable, V: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[P, V, X]](var function: F
) -> _IOMaskBody[NativeUnary[P, V, X, F, True], E] where P == Poll[E] and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == E and _ErrorCompatible[E, X]:
    """Adapt a raising native Poll factory, preserving its exact errors."""
    return uncancelable_with[E](NativeUnary[P, V, X, F, True](function^))
