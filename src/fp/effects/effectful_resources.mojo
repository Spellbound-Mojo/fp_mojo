"""Effectful resources over the shared native scope and finalization engine."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import UnaryContract, OnceUnary, BorrowCallContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._receiver import _OnceBorrowAvailable, _unary_once_as, _thunk_once_as
from fp.callables._binding import _OwnedUnary
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary, _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _ErrorCompatible, _CommonError, _propagate_error
from fp.data import Result, Ok, Err
from .protocols import ReaderAction
from .outcomes import Outcome, EffectFailure, ExitCase
from ._io_core import IO, IOContext, IOContract, _run_io, _settle
from .scoped import ScopedIO, _ScopedFactory, _run_scoped
from .finalization import Poll, _ConstantFinalizer, _finalize_outcome, _masked_factory
from .resources import Resource, _ResourceType, _OpenScope, _Releaser, _Lease, _DropResource, _HoldRelease, _Join, _MapScopeFactory, _ConstantResource, _scope_failure, _lease_outcome, _hold_leases


@fieldwise_init
struct _PlainRelease[R: UnaryContract & Movable & Deinitable](OnceUnary):
    var function: Self.R
    comptime Program = downcast[Self.R.Out, ReaderAction]
    comptime Arg = Self.R.Arg
    comptime Out = _ConstantFinalizer[Self.Program]
    comptime Error = Self.R.Error
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        var program = _unary_once_as[Self.Error](self.function^, value^)
        return _ConstantFinalizer(rebind_var[Self.Program](program^))


@fieldwise_init
struct _BoundRelease[R: UnaryContract & Movable & Deinitable](ScopedIO):
    var pending: _OwnedUnary[Self.R]
    comptime Factory = downcast[Self.R.Out, ScopedIO]
    comptime Input = Self.Factory.Input
    comptime Value = Self.Factory.Value
    comptime Error = Self.Factory.Error
    comptime BuildError = _CommonError[Self.R.Error, Self.Factory.BuildError]
    comptime Action[o: ImmOrigin] = Self.Factory.Action[o]
    # Complete the non-throwing owner transfer before entering either fallible
    # construction stage; unwinding must not retain a partially consumed self.
    def _take_pending(deinit self) -> _OwnedUnary[Self.R]:
        return self.pending^
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) raises Self.BuildError -> Self.Action[o]:
        comptime assert _ErrorCompatible[Self.Error, Self.R.Error] and _ErrorCompatible[Self.Error, Self.Factory.BuildError]
        comptime assert _ErrorCompatible[Self.BuildError, Self.R.Error] and _ErrorCompatible[Self.BuildError, Self.Factory.BuildError]
        var factory = rebind_var[Self.Factory](_thunk_once_as[Self.BuildError](self^._take_pending()))
        try:
            return factory^.build(value)
        except error:
            _propagate_error[Self.BuildError](error^)


@fieldwise_init
struct _EffectRelease[R: UnaryContract & Movable & Deinitable](_Releaser):
    var function: Self.R
    comptime Value = Self.R.Arg
    comptime Error = downcast[Self.R.Out, ScopedIO].Error
    def release[T: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[T, Self.Error], ref context: C) -> Outcome[T, Self.Error]:
        comptime assert C == IOContext[Self.Error]
        comptime assert downcast[Self.R.Out, ScopedIO].Input == ExitCase[Self.Error]
        var finalizer = _BoundRelease(_OwnedUnary(self.function^, value^))
        return _finalize_outcome(body^, finalizer^, rebind[IOContext[Self.Error]](context))


@fieldwise_init
struct _AcquireEffect[P: ReaderAction, R: UnaryContract & Movable & Deinitable](_OpenScope):
    var program: Self.P
    var release: Self.R
    comptime Release = _EffectRelease[Self.R]
    comptime Native = False
    comptime E = Self.Release.Error
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.E]:
        comptime assert C == IOContext[Self.E]
        comptime assert IOContract[Self.P].Compatible and IOContract[Self.P].Error == Self.E and Self.P.Value == Self.Release.Value
        ref env = rebind[IOContext[Self.E]](context)
        if env.canceled():
            return None
        var masked = env._mask()
        var acquired = _run_io(self.program^, rebind[IOContext[IOContract[Self.P].Error]](masked))
        # A successful value must reach its lease before cancellation is settled
        # in the enclosing context, even if acquisition requested cancellation.
        return _lease_outcome(rebind_var[Outcome[Self.Release.Value, Self.E]](acquired^), Self.Release(self.release^))


@fieldwise_init
struct _AcquireFull[F: UnaryContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](_OpenScope):
    var function: Self.F
    var release: Self.R
    comptime Release = _EffectRelease[Self.R]
    comptime Native = False
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.Release.Error]:
        comptime assert C == IOContext[Self.E] and Self.Release.Error == Self.E
        comptime assert downcast[Self.F.Out, ReaderAction].Value == Self.Release.Value
        ref env = rebind[IOContext[Self.E]](context)
        if env.canceled():
            return None
        var acquired = _masked_factory[Self.F, Self.E](self.function^, env)
        return rebind_var[Outcome[_Lease[Self.Release], Self.Release.Error]](_lease_outcome(rebind_var[Outcome[Self.Release.Value, Self.Release.Error]](acquired^), Self.Release(self.release^)))


@fieldwise_init
struct _EvaluateResource[P: ReaderAction](_OpenScope):
    var program: Self.P
    comptime E = IOContract[Self.P].Error
    comptime Release = _DropResource[Self.P.Value, Self.E]
    comptime Native = False
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.E]:
        comptime assert C == IOContext[Self.E] and IOContract[Self.P].Compatible
        var acquired = _run_io(self.program^, rebind[IOContext[Self.E]](context))
        return _lease_outcome(acquired^, Self.Release())


@fieldwise_init
struct _UseEffectResource[O: _OpenScope, F: ScopedIO](ReaderAction):
    var recipe: Self.O
    var function: Self.F
    comptime E = Self.F.Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.F.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert Self.O.Release.Error == Self.E and Self.F.Input == Self.O.Release.Value
        var opened = self.recipe^.open(env)
        if not opened or opened.value().is_err():
            return _settle(rebind_var[Self.Out[o]](_scope_failure[Self.Value](opened^)), env)
        var acquired = opened.take()
        var lease = acquired^._take_ok()
        var used = _run_scoped(self.function^, rebind[Self.F.Input](lease.value), env)
        return _settle(lease^.close(used^, env), env)


@fieldwise_init
struct _EvalMapResource[O: _OpenScope, F: ScopedIO, keep: Bool](_OpenScope):
    var recipe: Self.O
    var function: Self.F
    comptime E = Self.F.Error
    comptime Release = Self.O.Release if Self.keep else _HoldRelease[Self.O.Release, _DropResource[Self.F.Value, Self.E]]
    comptime Native = False
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.Release.Error]:
        comptime assert C == IOContext[Self.E] and Self.O.Release.Error == Self.E
        comptime assert Self.F.Input == Self.O.Release.Value and Self.Release.Error == Self.E
        comptime Output = Outcome[_Lease[Self.Release], Self.E]
        ref env = rebind[IOContext[Self.E]](context)
        var opened = self.recipe^.open(env)
        if not opened or opened.value().is_err():
            return rebind_var[Outcome[_Lease[Self.Release], Self.Release.Error]](_scope_failure[_Lease[Self.Release]](opened^))
        var acquired = opened.take()
        var left = acquired^._take_ok()
        var evaluated = _run_scoped(self.function^, rebind[Self.F.Input](left.value), env)
        if not evaluated or evaluated.value().is_err():
            var failed = _scope_failure[_Lease[Self.Release]](evaluated^)
            return rebind_var[Outcome[_Lease[Self.Release], Self.Release.Error]](left^.close(failed^, env))
        var result = evaluated.take()
        comptime if Self.keep:
            _ = result^
            return rebind_var[Outcome[_Lease[Self.Release], Self.Release.Error]](Optional(Result[_Lease[Self.Release], EffectFailure[Self.E]](Ok(rebind_var[_Lease[Self.Release]](left^)))))
        else:
            var right = _Lease[_DropResource[Self.F.Value, Self.E]](result^._take_ok(), _DropResource[Self.F.Value, Self.E]())
            return rebind_var[Outcome[_Lease[Self.Release], Self.Release.Error]](Optional(Result[_Lease[Self.Release], EffectFailure[Self.E]](Ok(rebind_var[_Lease[Self.Release]](_hold_leases(left^, right^))))))


@fieldwise_init
struct IOResource[O: _OpenScope](_ResourceType):
    """An inert resource whose acquisition, use and release compose IO effects.

    Default acquisition is masked until release is registered. Use is run in
    the enclosing cancellation state, and release is masked. Product and bind
    acquire left to right and finalize inside out, preserving every exact error.
    Dropping an unopened recipe destroys captures without executing effects.

    Parameters:
        O: The concrete shared acquisition recipe, inferred by constructors.
    """
    var _recipe: Self.O
    comptime Recipe = Self.O
    """The concrete recipe, retaining all captures and origins."""
    comptime Value = Self.O.Release.Value
    """The acquired value, borrowed by use and effectful projections."""
    comptime Error = Self.O.Release.Error
    """The exact error family shared by every lifecycle effect."""

    def _into_recipe(deinit self) -> Self.O:
        return self._recipe^

    def use[F: ScopedIO](deinit self, var function: F) -> _UseEffectResource[Self.O, F] where F.Input == Self.Value and F.Error == Self.Error and _ErrorCompatible[Self.Error, F.BuildError]:
        """Build a bracketed IO action, retaining the resource through use.

        Action[o] may borrow the acquired value while it runs. Completed values
        and errors must be independent of that fresh origin. A failed or canceled
        acquisition skips use; every registered release still runs exactly once.

        Parameters:
            F: A scoped IO factory over the acquired value.

        Args:
            function: The use factory, consumed and deferred.

        Returns:
            An IO program yielding F.Value, with all lifecycle errors retained.
        """
        return _UseEffectResource(self._recipe^, function^)

    def product[R: _ResourceType](deinit self, var right: R) -> IOResource[_Join[Self.O, _ConstantResource[Self.Value, R], True]] where R.Recipe.Release.Error == Self.Error:
        """Acquire two scopes and expose their owned native pair.

        Parameters:
            R: A native or effectful right resource in the same error family.

        Args:
            right: The unopened right scope, consumed.

        Returns:
            A scope releasing right then left, including after partial failure.
        """
        return IOResource(_Join[Self.O, _ConstantResource[Self.Value, R], True](self._recipe^, _ConstantResource[Self.Value, R](right^)))

    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> IOResource[_Join[Self.O, F, False]] where F.Payload == Self.Value and conforms_to(F.Result, _ResourceType) and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.Error, F.Failure] and downcast[F.Result, _ResourceType].Recipe.Release.Error == Self.Error:
        """Derive an inner resource while retaining the outer resource.

        The inner recipe is independent of the fresh input borrow; captured
        independent origins remain supported. For an effect that borrows the
        outer value during execution, use eval_map or eval_tap instead.

        Parameters:
            F: A borrowing factory of a native or effectful resource.

        Args:
            function: The factory, consumed and deferred until acquisition.

        Returns:
            The inner scope, with outer release registered behind inner release.
        """
        return IOResource(_Join[Self.O, F, False](self._recipe^, function^))

    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> IOResource[_Join[Self.O, _MapScopeFactory[F, Self.Error], False]] where F.Payload == Self.Value and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.Error, F.Failure]:
        """Project an owned value, retaining the original scope until release.

        Parameters:
            F: A native borrowing projection with compatible exact errors.

        Args:
            function: The deferred projection, consumed.

        Returns:
            A resource of the projection, sharing the native map derivation.
        """
        return self^.flat_map(_MapScopeFactory[F, Self.Error](function^))

    def eval_map[F: ScopedIO](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, F, False]] where F.Input == Self.Value and F.Error == Self.Error and _ErrorCompatible[Self.Error, F.BuildError]:
        """Project through a cancellable effect while the original resource lives.

        Parameters:
            F: A scoped IO factory over the acquired value.

        Args:
            function: The deferred effectful projection, consumed.

        Returns:
            A resource of F.Value, retaining outer release after native result destruction.
        """
        return IOResource(_EvalMapResource[Self.O, F, False](self._recipe^, function^))

    def eval_tap[F: ScopedIO](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, F, True]] where F.Input == Self.Value and F.Error == Self.Error and _ErrorCompatible[Self.Error, F.BuildError]:
        """Run a cancellable effect and retain the original acquired value.

        Parameters:
            F: A scoped IO factory over the acquired value.

        Args:
            function: The deferred effect, whose successful result is discarded.

        Returns:
            The original resource after the effect; failure or cancellation releases it.
        """
        return IOResource(_EvalMapResource[Self.O, F, True](self._recipe^, function^))

    def surround[P: ReaderAction](deinit self, var program: P) -> _UseEffectResource[Self.O, _ConstantFinalizer[P, Self.Value]] where IOContract[P].Compatible and IOContract[P].Error == Self.Error:
        """Run an independent program inside this resource's lifetime.

        Parameters:
            P: An IO program in the resource's error family.

        Args:
            program: The program, consumed and deferred.

        Returns:
            An IO program with the supplied program's value type.
        """
        return self^.use(_ConstantFinalizer[P, Self.Value](program^))


    def use[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> _UseEffectResource[Self.O, _ScopedFactory[F]] where F.Payload == Self.Value and _OnceBorrowAvailable[F] and conforms_to(F.Result, ReaderAction) and IOContract[downcast[F.Result, ReaderAction]].Compatible and IOContract[downcast[F.Result, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, F.Failure]:
        """Adapt an input-independent IO factory to the shared scoped runner."""
        var adapted = _ScopedFactory(function^)
        return self^.use(adapted^)

    def use[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F) -> _UseEffectResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, Never, F, False]]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, Never]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.use(_NativeBorrow[P, V, Never, F, False](function^))

    def use[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F) -> _UseEffectResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, X, F, True]]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, X]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.use(_NativeBorrow[P, V, X, F, True](function^))

    def eval_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[F], False]] where F.Payload == Self.Value and _OnceBorrowAvailable[F] and conforms_to(F.Result, ReaderAction) and IOContract[downcast[F.Result, ReaderAction]].Compatible and IOContract[downcast[F.Result, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, F.Failure]:
        """Adapt an input-independent IO factory to the shared scoped runner."""
        var adapted = _ScopedFactory(function^)
        return self^.eval_map(adapted^)

    def eval_map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, Never, F, False]], False]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, Never]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.eval_map(_NativeBorrow[P, V, Never, F, False](function^))

    def eval_map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, X, F, True]], False]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, X]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.eval_map(_NativeBorrow[P, V, X, F, True](function^))

    def eval_tap[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[F], True]] where F.Payload == Self.Value and _OnceBorrowAvailable[F] and conforms_to(F.Result, ReaderAction) and IOContract[downcast[F.Result, ReaderAction]].Compatible and IOContract[downcast[F.Result, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, F.Failure]:
        """Adapt an input-independent IO factory to the shared scoped runner."""
        var adapted = _ScopedFactory(function^)
        return self^.eval_tap(adapted^)

    def eval_tap[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, Never, F, False]], True]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, Never]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.eval_tap(_NativeBorrow[P, V, Never, F, False](function^))

    def eval_tap[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F) -> IOResource[_EvalMapResource[Self.O, _ScopedFactory[_NativeBorrow[P, V, X, F, True]], True]] where P == Self.Value and conforms_to(V, ReaderAction) and IOContract[downcast[V, ReaderAction]].Compatible and IOContract[downcast[V, ReaderAction]].Error == Self.Error and _ErrorCompatible[Self.Error, X]:
        """Adapt a native borrowing IO factory without executing it."""
        return self^.eval_tap(_NativeBorrow[P, V, X, F, True](function^))

    def map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F) -> IOResource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, Never, F, False], Self.Error], False]] where P == Self.Value and _ErrorCompatible[Self.Error, Never]:
        """Adapt a native borrowing callback to the shared resource derivation."""
        return self^.map(_NativeBorrow[P, V, Never, F, False](function^))

    def map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F) -> IOResource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, X, F, True], Self.Error], False]] where P == Self.Value and _ErrorCompatible[Self.Error, X]:
        """Adapt a native borrowing callback to the shared resource derivation."""
        return self^.map(_NativeBorrow[P, V, X, F, True](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F) -> IOResource[_Join[Self.O, _NativeBorrow[P, V, Never, F, False], False]] where P == Self.Value and _ErrorCompatible[Self.Error, Never] and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt a native borrowing callback to the shared resource derivation."""
        return self^.flat_map(_NativeBorrow[P, V, Never, F, False](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F) -> IOResource[_Join[Self.O, _NativeBorrow[P, V, X, F, True], False]] where P == Self.Value and _ErrorCompatible[Self.Error, X] and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt a native borrowing callback to the shared resource derivation."""
        return self^.flat_map(_NativeBorrow[P, V, X, F, True](function^))


struct IOResourceContract[P: ReaderAction, R: UnaryContract & Movable & Deinitable]:
    """Admission and concrete type for an IO resource with ordinary release.

    Parameters:
        P: The acquisition program, including its value and error family.
        R: The consuming factory of a release IO program.
    """
    comptime E = IOContract[Self.P].Error
    """The exact selected error family."""
    comptime Compatible = IOContract[Self.P].Compatible and Self.P.Value == Self.R.Arg and _OnceUnaryAvailable[Self.R] and _ErrorCompatible[Self.E, Self.R.Error] and conforms_to(Self.R.Out, ReaderAction) and IOContract[downcast[Self.R.Out, ReaderAction]].Compatible and IOContract[downcast[Self.R.Out, ReaderAction]].Error == Self.E
    """Exact acquired input, IO families and compatible construction errors."""
    comptime Out = IOResource[_AcquireEffect[Self.P, _PlainRelease[Self.R]]]
    """The unopened concrete resource, retaining every owner and origin."""


struct IOResourceCaseContract[P: ReaderAction, R: UnaryContract & Movable & Deinitable]:
    """Admission and type for release that borrows the exact exit case.

    Parameters:
        P: The acquisition IO program.
        R: A consuming factory returning ScopedIO over ExitCase.
    """
    comptime E = IOContract[Self.P].Error
    """The exact selected error family."""
    comptime Factory = downcast[Self.R.Out, ScopedIO]
    """The release factory after it owns the acquired resource."""
    comptime Compatible = IOContract[Self.P].Compatible and Self.P.Value == Self.R.Arg and _OnceUnaryAvailable[Self.R] and _ErrorCompatible[Self.E, Self.R.Error] and conforms_to(Self.R.Out, ScopedIO) and Self.Factory.Input == ExitCase[Self.E] and Self.Factory.Error == Self.E and _ErrorCompatible[Self.E, Self.Factory.BuildError]
    """Exact acquired input, exit-case input and compatible native errors."""
    comptime Out = IOResource[_AcquireEffect[Self.P, Self.R]]
    """The unopened concrete resource with case-aware release."""


struct IOResourceFullContract[F: UnaryContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable, case_release: Bool = False]:
    """Admission and type for controlled cancellation during acquisition.

    Parameters:
        F: A consuming factory from Poll[E] to an IO program.
        R: The consuming release factory.
        E: The selected error family.
        case_release: Whether release returns ScopedIO over ExitCase instead of IO.
    """
    comptime Program = downcast[Self.F.Out, ReaderAction]
    """The acquisition program produced under the mask."""
    comptime Release = Self.R if Self.case_release else _PlainRelease[Self.R]
    """The normalized exit-aware release factory."""
    comptime Compatible = Self.F.Arg == Poll[Self.E] and _OnceUnaryAvailable[Self.F] and _ErrorCompatible[Self.E, Self.F.Error] and conforms_to(Self.F.Out, ReaderAction) and IOContract[Self.Program].Error == Self.E and (IOResourceCaseContract[Self.Program, Self.R].Compatible if Self.case_release else IOResourceContract[Self.Program, Self.R].Compatible)
    """Compatible Poll, acquisition, value, release and exact error types."""
    comptime Out = IOResource[_AcquireFull[Self.F, Self.Release, Self.E]]
    """The unopened full-acquisition resource type."""


def resource_io[P: ReaderAction, R: UnaryContract & Movable & Deinitable](var acquire: P, var release: R) -> IOResourceContract[P, R].Out where IOResourceContract[P, R].Compatible:
    """Describe effectful acquisition and release without executing either.

    Acquisition and release are masked. Release consumes the acquired value
    and returns IO in the same error family; its successful result is discarded.
    Cancellation arriving during acquisition cannot abandon a successful value
    before its release is registered. Use remains cancellable.

    Parameters:
        P: The acquisition IO program.
        R: The consuming release factory.

    Args:
        acquire: The unopened acquisition program, consumed.
        release: The deferred release factory, consumed.

    Returns:
        An IOResource whose use method constructs a bracketed IO program.
    """
    return IOResource(_AcquireEffect[P, _PlainRelease[R]](acquire^, _PlainRelease(release^)))


def resource_io_case[P: ReaderAction, R: UnaryContract & Movable & Deinitable](var acquire: P, var release: R) -> IOResourceCaseContract[P, R].Out where IOResourceCaseContract[P, R].Compatible:
    """Describe release that observes the protected scope's exact exit case.

    Release first consumes the resource into a ScopedIO factory over ExitCase[E].
    That factory may retain a borrow of the exit case during its IO action.
    Both construction stages and execution are masked and capture exact errors.
    The two-stage signature separates owned resource transfer from borrowed exit
    information without requiring copyable resources or errors.

    Parameters:
        P: The acquisition IO program.
        R: A consuming factory returning ScopedIO over ExitCase[E].

    Args:
        acquire: The unopened masked acquisition, consumed.
        release: The deferred consuming release factory.

    Returns:
        An effectful resource with case-aware finalization.
    """
    return IOResource(_AcquireEffect[P, R](acquire^, release^))


def resource_io_full[F: UnaryContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var acquire: F, var release: R) -> IOResourceFullContract[F, R, E].Out where IOResourceFullContract[F, R, E].Compatible:
    """Pass Poll to acquisition so selected waiting can be canceled safely.

    The factory and ordinary acquisition steps run masked. Poll restores the
    enclosing cancellation state for selected subprograms. A canceled or failed
    acquisition must clean up its own partial work; registered release begins
    only after a successful value is returned. Keep the final handoff masked.

    Parameters:
        F: A consuming factory from Poll[E] to IO[E].
        R: The consuming factory of a release IO program.
        E: The selected exact error family.

    Args:
        acquire: The deferred acquisition factory, consumed.
        release: The deferred release factory, consumed.

    Returns:
        A resource with controlled cancellable acquisition and masked release.
    """
    return IOResource(_AcquireFull[F, _PlainRelease[R], E](acquire^, _PlainRelease(release^)))


def resource_io_case_full[F: UnaryContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var acquire: F, var release: R) -> IOResourceFullContract[F, R, E, True].Out where IOResourceFullContract[F, R, E, True].Compatible:
    """Combine controlled acquisition cancellation with exit-aware release.

    Parameters:
        F: A consuming factory from Poll[E] to IO[E].
        R: A consuming factory returning ScopedIO over ExitCase[E].
        E: The selected exact error family.

    Args:
        acquire: The deferred acquisition factory, consumed.
        release: The deferred exit-aware release factory, consumed.

    Returns:
        A full-acquisition resource retaining the same ownership and cleanup rules.
    """
    return IOResource(_AcquireFull[F, R, E](acquire^, release^))


def eval_resource[P: ReaderAction](var program: P) -> IOResource[_EvaluateResource[P]] where IOContract[P].Compatible:
    """Lift a cancellable IO action into a resource with native value destruction.

    Parameters:
        P: An IO program in any selected error family.

    Args:
        program: The deferred action, consumed.

    Returns:
        A resource that holds the successful value through use, with no custom release.
    """
    return IOResource(_EvaluateResource(program^))


def lift_resource[O: _OpenScope](var scope: Resource[O]) -> IOResource[O] where O.Native:
    """Use a native resource in effectful composition through the same recipe.

    The native callbacks retain their synchronous signatures. IO use effects
    can borrow the acquired value while running. Partial acquisition cleanup
    and reverse release order remain owned by the shared scope engine.

    Parameters:
        O: A native resource recipe.

    Args:
        scope: The unopened native scope, consumed without acquiring it.

    Returns:
        An effectful view of the same acquisition and release recipe.
    """
    return IOResource(scope^._into_recipe())


def resource_io[P: ReaderAction, T: Movable & Deinitable, V: Movable & Deinitable, //, R: _Unary[T, V]](var acquire: P, var release: R) -> IOResourceContract[P, NativeUnary[T, V, Never, R, False]].Out where IOResourceContract[P, NativeUnary[T, V, Never, R, False]].Compatible:
    """Adapt a native consuming release factory through the canonical callable owner."""
    return resource_io(acquire^, NativeUnary[T, V, Never, R, False](release^))


def resource_io[P: ReaderAction, T: Movable & Deinitable, V: Movable & Deinitable, X: Movable & Deinitable, //, R: _RaisingUnary[T, V, X]](var acquire: P, var release: R) -> IOResourceContract[P, NativeUnary[T, V, X, R, True]].Out where IOResourceContract[P, NativeUnary[T, V, X, R, True]].Compatible:
    """Adapt a native consuming release factory through the canonical callable owner."""
    return resource_io(acquire^, NativeUnary[T, V, X, R, True](release^))


def resource_io_case[P: ReaderAction, T: Movable & Deinitable, V: Movable & Deinitable, //, R: _Unary[T, V]](var acquire: P, var release: R) -> IOResourceCaseContract[P, NativeUnary[T, V, Never, R, False]].Out where IOResourceCaseContract[P, NativeUnary[T, V, Never, R, False]].Compatible:
    """Adapt a native consuming release factory through the canonical callable owner."""
    return resource_io_case(acquire^, NativeUnary[T, V, Never, R, False](release^))


def resource_io_case[P: ReaderAction, T: Movable & Deinitable, V: Movable & Deinitable, X: Movable & Deinitable, //, R: _RaisingUnary[T, V, X]](var acquire: P, var release: R) -> IOResourceCaseContract[P, NativeUnary[T, V, X, R, True]].Out where IOResourceCaseContract[P, NativeUnary[T, V, X, R, True]].Compatible:
    """Adapt a native consuming release factory through the canonical callable owner."""
    return resource_io_case(acquire^, NativeUnary[T, V, X, R, True](release^))


def resource_io_full[F: UnaryContract & Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[F, NativeUnary[T, V, Never, R, False], E].Out where IOResourceFullContract[F, NativeUnary[T, V, Never, R, False], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = acquire^
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[F: UnaryContract & Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[F, NativeUnary[T, V, Y, R, True], E].Out where IOResourceFullContract[F, NativeUnary[T, V, Y, R, True], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = acquire^
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], R, E].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], R, E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = release^
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B], R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Never, R, False], E].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Never, R, False], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B], R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Y, R, True], E].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Y, R, True], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], R, E].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], R, E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = release^
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X], R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Never, R, False], E].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Never, R, False], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X], R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Y, R, True], E].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Y, R, True], E].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_full[E](acquisition^, finalizer^)


def resource_io_case_full[F: UnaryContract & Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[F, NativeUnary[T, V, Never, R, False], E, True].Out where IOResourceFullContract[F, NativeUnary[T, V, Never, R, False], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = acquire^
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[F: UnaryContract & Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[F, NativeUnary[T, V, Y, R, True], E, True].Out where IOResourceFullContract[F, NativeUnary[T, V, Y, R, True], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = acquire^
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], R, E, True].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], R, E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = release^
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B], R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Never, R, False], E, True].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Never, R, False], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[A, B], R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Y, R, True], E, True].Out where IOResourceFullContract[NativeUnary[A, B, Never, F, False], NativeUnary[T, V, Y, R, True], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, Never, F, False](acquire^)
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], R, E, True].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], R, E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = release^
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X], R: _Unary[T, V]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Never, R, False], E, True].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Never, R, False], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = NativeUnary[T, V, Never, R, False](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)


def resource_io_case_full[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, T: Movable & Deinitable, V: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, B, X], R: _RaisingUnary[T, V, Y]](var acquire: F, var release: R) -> IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Y, R, True], E, True].Out where IOResourceFullContract[NativeUnary[A, B, X, F, True], NativeUnary[T, V, Y, R, True], E, True].Compatible:
    """Adapt native acquisition or release through the shared callable owners."""
    var acquisition = NativeUnary[A, B, X, F, True](acquire^)
    var finalizer = NativeUnary[T, V, Y, R, True](release^)
    return resource_io_case_full[E](acquisition^, finalizer^)
