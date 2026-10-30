"""Outcome-aware finalization and lexically restored cancellation regions."""
from std.builtin.rebind import downcast, rebind_var
from std.memory import ArcPointer
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Err
from .protocols import ReaderAction, Defer, Raise, Cancel
from .outcomes import Outcome, EffectFailure, ExitCase, _ExitState, _capture, _finish
from ._io_core import IO, IOContext, IOContract, _run_io, _settle, _IODelay, _IODefer, _IOCancel, _SyncDefers, canceled
from fp.callables.protocols import ThunkContract
from fp.callables.invoke import _OnceThunkAvailable
from fp.data import NonEmptyList
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


def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable, //, I: Cancel](var program: V, var finalizer: Q) -> I.Guaranteed[V, Q] where I.GuaranteeCompatible[V, Q]:
    """Run a finalizer, masked, after the program on every exit, in any family with Cancel.

    Parameters:
        V: The program's carrier type.
        Q: The finalizer's unit carrier type.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        program: The program, consumed.
        finalizer: The finalizer, consumed.

    Returns:
        The family's guarded carrier.
    """
    return I.guarantee(program^, finalizer^)


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


def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable, //, I: Cancel](var program: V, var finalizer: Q) -> I.OnCanceled[V, Q] where I.GuaranteeCompatible[V, Q]:
    """Run a finalizer, masked, only if the program is canceled, in any family with Cancel.

    Parameters:
        V: The program's carrier type.
        Q: The finalizer's unit carrier type.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        program: The program, consumed.
        finalizer: The finalizer, consumed.

    Returns:
        The family's guarded carrier.
    """
    return I.on_cancel(program^, finalizer^)


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


def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable, //, I: Cancel](var program: V, var finalizer: F) -> I.CaseGuaranteed[V, F] where I.CaseCompatible[V, F]:
    """Run a finalizer built from the exact exit, masked, in any family with Cancel.

    Parameters:
        V: The program's carrier type.
        F: The family's finalizer type, built from the exit.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        program: The program, consumed.
        finalizer: The finalizer, consumed.

    Returns:
        The family's guarded carrier.
    """
    return I.guarantee_case(program^, finalizer^)


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
    def _restore(self, env: IOContext[Self.E]) -> IOContext[Self.E]:
        # Restore lexical cancellation state while keeping the current task's
        # scheduler parent, clock and token. Child contexts own their regions.
        var restored = env.copy()
        if env._region and env._region.value().ptr() == self._region.ptr():
            restored._masked = self._previous._masked
            restored._region = self._previous._region.copy()
        return restored^
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
        var restored = self.poll._restore(env)
        return rebind_var[Self.Out[o]](_run_io(self.program^, rebind[IOContext[IOContract[Self.P].Error]](restored)))


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


comptime _SyncFinalizes[E: Movable & Deinitable, V: Movable & Deinitable, Q: Movable & Deinitable] = (
    _FinalizerCompatible[downcast[V, ReaderAction], downcast[Q, ReaderAction]]
    and IOContract[downcast[V, ReaderAction]].Error == E) if conforms_to(V, ReaderAction) and conforms_to(Q, ReaderAction) else False


comptime _SyncCase[E: Movable & Deinitable, V: Movable & Deinitable, F: Movable & Deinitable] = (
    _CaseFinalizerCompatible[downcast[V, ReaderAction], downcast[F, ScopedIO]]
    and IOContract[downcast[V, ReaderAction]].Error == E) if conforms_to(V, ReaderAction) and conforms_to(F, ScopedIO) else False


comptime _SyncMasks[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = (
    F.Arg == Poll[E] and _OnceUnaryAvailable[F] and _ErrorCompatible[E, F.Error]
    and IOContract[downcast[F.Out, ReaderAction]].Compatible
    and IOContract[downcast[F.Out, ReaderAction]].Error == E) if conforms_to(F.Out, ReaderAction) else False


struct SyncIO[E: Movable & Deinitable](Defer, Raise, Cancel, not Deinitable):
    """The capabilities of the synchronous IO[E] family: Defer, Raise and Cancel.

    Generic code names this dictionary to run in IO[E], such as
    `guarantee[SyncIO[E]](program, cleanup)`. Each operation forwards to the
    family's existing function. The synchronous family has no fibers, so
    SyncIO is not a Spawn provider.

    Parameters:
        E: The exact domain error of the IO[E] family.
    """
    comptime Family = IO[Self.E]
    comptime Error = Self.E
    comptime DelayCompatible[F: ThunkContract & Movable & Deinitable] = _ErrorCompatible[Self.E, F.Error] and _OnceThunkAvailable[F]
    comptime Delayed[F: ThunkContract & Movable & Deinitable] = _IODelay[Self.E, F]
    comptime DeferCompatible[F: ThunkContract & Movable & Deinitable] = _SyncDefers[Self.E, F]
    comptime Deferred[F: ThunkContract & Movable & Deinitable] = _IODefer[Self.E, F]
    comptime Raised[A: Movable & Deinitable] = IO[Self.E].Failed[A]
    comptime RegionPoll = Poll[Self.E]
    comptime Canceled = _IOCancel[Self.E]
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = _SyncFinalizes[Self.E, V, Q]
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = _IOGuarantee[downcast[V, ReaderAction], downcast[Q, ReaderAction]]
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = _IOGuarantee[downcast[V, ReaderAction], downcast[Q, ReaderAction], True]
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = _SyncCase[Self.E, V, F]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = _IOGuaranteeCase[downcast[V, ReaderAction], downcast[F, ScopedIO]]
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = _SyncMasks[Self.E, F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = _IOMaskBody[F, Self.E]
    comptime RestoreCompatible[V: Movable & Deinitable] = (IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.E) if conforms_to(V, ReaderAction) else False
    comptime Restored[V: Movable & Deinitable] = _IOPolled[downcast[V, ReaderAction], Self.E]

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Delayed[F]:
        """Run a function when reached; see delay.

        Parameters:
            F: An owned once-callable thunk with error E or none.

        Args:
            function: The function, consumed.

        Returns:
            An IO[E] program producing its value.
        """
        comptime assert Self.DelayCompatible[F]
        return _IODelay[Self.E, F](function^)

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self.Deferred[F]:
        """Build a program when reached, then run it.

        Parameters:
            F: An owned once-callable returning an IO[E] program.

        Args:
            factory: The factory, consumed.

        Returns:
            An IO[E] program running the program the factory builds.
        """
        comptime assert Self.DeferCompatible[F]
        return _IODefer[Self.E, F](factory^)

    @staticmethod
    def raise_error[A: Movable & Deinitable](var error: Self.E) -> Self.Raised[A]:
        """Fail with one ordinary error.

        Parameters:
            A: The success type.

        Args:
            error: The error, consumed.

        Returns:
            An IO[E] program failing with an uncanceled failure holding the error.
        """
        return IO[Self.E].fail[A](EffectFailure[Self.E](NonEmptyList(error^), False))

    @staticmethod
    def canceled() -> Self.Canceled:
        """Request cancellation; see canceled.

        Returns:
            A unit IO[E] program.
        """
        return canceled[Self.E]()

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Finalize on every exit; see guarantee.

        Parameters:
            V: An IO[E] program.
            Q: A unit IO[E] program.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The guarded program.
        """
        comptime assert conforms_to(V, ReaderAction) and conforms_to(Q, ReaderAction)
        comptime assert _FinalizerCompatible[downcast[V, ReaderAction], downcast[Q, ReaderAction]]
        return guarantee(rebind_var[downcast[V, ReaderAction]](program^), rebind_var[downcast[Q, ReaderAction]](finalizer^))

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Finalize only on cancellation; see on_cancel.

        Parameters:
            V: An IO[E] program.
            Q: A unit IO[E] program.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The guarded program.
        """
        comptime assert conforms_to(V, ReaderAction) and conforms_to(Q, ReaderAction)
        comptime assert _FinalizerCompatible[downcast[V, ReaderAction], downcast[Q, ReaderAction]]
        return on_cancel(rebind_var[downcast[V, ReaderAction]](program^), rebind_var[downcast[Q, ReaderAction]](finalizer^))

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Finalize with an effect borrowing the exact exit; see guarantee_case.

        Parameters:
            V: An IO[E] program.
            F: A ScopedIO borrowing ExitCase[E].

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The guarded program.
        """
        comptime assert conforms_to(V, ReaderAction) and conforms_to(F, ScopedIO)
        comptime assert _CaseFinalizerCompatible[downcast[V, ReaderAction], downcast[F, ScopedIO]]
        return guarantee_case(rebind_var[downcast[V, ReaderAction]](program^), rebind_var[downcast[F, ScopedIO]](finalizer^))

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Poll[Self.E], var program: V) -> Self.Restored[V]:
        """Run part of a region with the outer cancellation state; see Poll.apply.

        Parameters:
            V: An IO[E] program.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The restored program.
        """
        comptime assert conforms_to(V, ReaderAction)
        comptime assert IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.E
        return poll.apply(rebind_var[downcast[V, ReaderAction]](program^))

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Run a region masked; see uncancelable_with.

        Parameters:
            F: An owned once-callable from Poll[E] to an IO[E] program.

        Args:
            body: The region's factory, consumed.

        Returns:
            The masked program.
        """
        comptime assert F.Arg == Poll[Self.E] and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and conforms_to(F.Out, ReaderAction)
        comptime assert IOContract[downcast[F.Out, ReaderAction]].Compatible and IOContract[downcast[F.Out, ReaderAction]].Error == Self.E
        return uncancelable_with[Self.E](body^)
