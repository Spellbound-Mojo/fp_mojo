"""Consumed native resource recipes with explicit, composable finalization."""
from std.builtin.rebind import downcast, rebind_var
from std.memory import MaybeUninit
from fp.callables.protocols import ThunkContract, UnaryContract, BorrowCallContract, BorrowOnceCallable
from fp.callables.invoke import _OnceThunkAvailable, _OnceUnaryAvailable
from fp.callables._receiver import _OnceBorrowAvailable, _borrow_once_as
from fp.callables._binding import _OwnedThunk, _OwnedUnary, _BorrowThunk
from fp.callables._transforms import _IgnoreInput, _ValueThunk
from fp.callables.products import _take_pair
from fp.callables.native import _NativeThunk, NativeUnary, _NativeBorrow, _Thunk, _RaisingThunk, _Unary, _RaisingUnary, _Borrowing, _RaisingBorrowing
from fp.data import Result, Ok, Err
from fp._internal.errors import _ErrorCompatible
from .outcomes import EffectFailure, Outcome, _capture, _finish
from ._io_core import IOContext, delay
from .finalization import _finalize_outcome, _ConstantFinalizer


def _scope_canceled[C: AnyType, E: Movable & Deinitable](ref context: C) -> Bool:
    # Native scopes carry a unit context: no cancellation token or mask is
    # allocated. IO scopes use the same lifecycle with their exact context.
    comptime if C == NoneType:
        return False
    else:
        comptime assert C == IOContext[E]
        return rebind[IOContext[E]](context).canceled()


trait _Releaser(Movable, Deinitable):
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def release[T: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[T, Self.Error], ref context: C) -> Outcome[T, Self.Error]:
        ...


@fieldwise_init
struct _Lease[R: _Releaser](Movable):
    var value: Self.R.Value
    var releaser: Self.R
    def close[T: Movable & Deinitable, E: Movable & Deinitable, C: AnyType](deinit self, var body: Outcome[T, E], ref context: C) -> Outcome[T, E] where E == Self.R.Error:
        # Composition names the same error through conditional releaser types.
        # Admit exact identity here and normalize those nominal spellings once.
        return rebind_var[Outcome[T, E]](self.releaser^.release(self.value^, rebind_var[Outcome[T, Self.R.Error]](body^), context))
    def into_parts(deinit self) -> Tuple[Self.R.Value, Self.R]:
        return (self.value^, self.releaser^)


trait _OpenScope(Movable, Deinitable):
    comptime Release: _Releaser
    comptime Native: Bool = True
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.Release.Error]:
        ...


@fieldwise_init
struct _DropResource[T: Movable & Deinitable, E: Movable & Deinitable](_Releaser):
    comptime Value = Self.T
    comptime Error = Self.E
    def release[U: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[U, Self.Error], ref context: C) -> Outcome[U, Self.Error]:
        _ = value^
        return body^


@fieldwise_init
struct _PureResource[T: Movable & Deinitable, E: Movable & Deinitable](_OpenScope):
    var value: Self.T
    comptime Release = _DropResource[Self.T, Self.E]
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.E]:
        if _scope_canceled[C, Self.E](context):
            return None
        return Optional(Result[_Lease[Self.Release], EffectFailure[Self.E]](Ok(_Lease[Self.Release](self.value^, Self.Release()))))


@fieldwise_init
struct _MapScopeFactory[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](BorrowOnceCallable):
    var function: Self.F
    comptime Payload = Self.F.Payload
    comptime Result = Resource[_PureResource[Self.F.Result, Self.E]]
    comptime Failure = Self.F.Failure
    def invoke_once(deinit self, ref value: Self.Payload) raises Self.Failure -> Self.Result:
        return pure_resource[Self.E](_borrow_once_as[Self.Failure](value, self.function^))


trait _ResourceType(Movable, Deinitable):
    comptime Recipe: _OpenScope
    def _into_recipe(deinit self) -> Self.Recipe:
        ...


@fieldwise_init
struct _NativeRelease[R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](_Releaser):
    var function: Self.R
    comptime Value = Self.R.Arg
    comptime Error = Self.E
    def release[T: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[T, Self.Error], ref context: C) -> Outcome[T, Self.Error]:
        comptime assert _ErrorCompatible[Self.E, Self.R.Error]
        var callback = _OwnedUnary(self.function^, value^)
        comptime if C == NoneType:
            # The native boundary captures synchronously without IO machinery;
            # both routes retain the same callback owner and outcome combiner.
            return _finish(body^, Optional(_capture[Self.E](callback^)))
        else:
            comptime assert C == IOContext[Self.E]
            var cleanup = delay[Self.E](callback^)
            var finalizer = _ConstantFinalizer(cleanup^)
            return _finalize_outcome(body^, finalizer^, rebind[IOContext[Self.E]](context))


@fieldwise_init
struct _Acquire[A: ThunkContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](_OpenScope):
    var acquire: Self.A
    var release: Self.R
    comptime Release = _NativeRelease[Self.R, Self.E]
    comptime Value = Self.Release.Value
    comptime Error = Self.Release.Error
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.Error]:
        comptime assert Self.A.Out == Self.R.Arg and _ErrorCompatible[Self.E, Self.A.Error]
        if _scope_canceled[C, Self.Error](context):
            return None
        var acquired = _capture[Self.E](_OwnedThunk(self.acquire^))
        # Register release before returning to any unmasked cancellation check.
        return _lease_outcome(Optional(acquired^), Self.Release(self.release^))


def _close_two[L: _Releaser, R: _Releaser, T: Movable & Deinitable, C: AnyType](var left: _Lease[L], var right: _Lease[R], var body: Outcome[T, L.Error], ref context: C
) -> Outcome[T, L.Error]:
    comptime assert L.Error == R.Error
    var closed_right = right^.close(rebind_var[Outcome[T, R.Error]](body^), context)
    # The outer finalizer observes the completed inner scope, including errors
    # and cancellation from inner cleanup. No error payload is copied.
    return left^.close(rebind_var[Outcome[T, L.Error]](closed_right^), context)


@fieldwise_init
struct _PairRelease[L: _Releaser, R: _Releaser](_Releaser):
    var left: Self.L
    var right: Self.R
    comptime Value = Tuple[Self.L.Value, Self.R.Value]
    comptime Error = Self.L.Error
    def release[T: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[T, Self.Error], ref context: C) -> Outcome[T, Self.Error]:
        var left_slot = MaybeUninit[Self.L.Value]()
        var right_slot = MaybeUninit[Self.R.Value]()
        _take_pair(value^, left_slot, right_slot)
        var left = _Lease(left_slot^.unsafe_assume_init(), self.left^)
        var right = _Lease(right_slot^.unsafe_assume_init(), self.right^)
        return _close_two(left^, right^, body^, context)


@fieldwise_init
struct _HoldRelease[L: _Releaser, R: _Releaser](_Releaser):
    var left: _Lease[Self.L]
    var right: Self.R
    comptime Value = Self.R.Value
    comptime Error = Self.L.Error
    def release[T: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[T, Self.Error], ref context: C) -> Outcome[T, Self.Error]:
        return _close_two(self.left^, _Lease(value^, self.right^), body^, context)


def _pair_leases[L: _Releaser, R: _Releaser](var left: _Lease[L], var right: _Lease[R]) -> _Lease[_PairRelease[L, R]]:
    var left_value = MaybeUninit[L.Value]()
    var left_release = MaybeUninit[L]()
    var right_value = MaybeUninit[R.Value]()
    var right_release = MaybeUninit[R]()
    _take_pair(left^.into_parts(), left_value, left_release)
    _take_pair(right^.into_parts(), right_value, right_release)
    return _Lease[_PairRelease[L, R]]((left_value^.unsafe_assume_init(), right_value^.unsafe_assume_init()), _PairRelease(left_release^.unsafe_assume_init(), right_release^.unsafe_assume_init()))


def _hold_leases[L: _Releaser, R: _Releaser](var left: _Lease[L], var right: _Lease[R]) -> _Lease[_HoldRelease[L, R]]:
    var value = MaybeUninit[R.Value]()
    var release = MaybeUninit[R]()
    _take_pair(right^.into_parts(), value, release)
    return _Lease[_HoldRelease[L, R]](value^.unsafe_assume_init(), _HoldRelease(left^, release^.unsafe_assume_init()))


@fieldwise_init
struct _ConstantResource[T: AnyType, R: _ResourceType](BorrowOnceCallable):
    var right: Self.R
    comptime Payload = Self.T
    comptime Result = Self.R
    def invoke_once(deinit self, ref value: Self.Payload) -> Self.Result:
        return self.right^


def _scope_failure[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](var failure: Outcome[U, E]) -> Outcome[T, E]:
    """Retype an already-checked unsuccessful acquisition without losing errors."""
    if not failure:
        return None
    var result = failure.take()
    return Optional(Result[T, EffectFailure[E]](Err(result^._take_err())))


def _lease_outcome[T: Movable & Deinitable, E: Movable & Deinitable, R: _Releaser](var acquired: Outcome[T, E], var release: R
) -> Outcome[_Lease[R], E] where T == R.Value and E == R.Error:
    if not acquired or acquired.value().is_err():
        return _scope_failure[_Lease[R]](acquired^)
    var result = acquired.take()
    return Optional(Result[_Lease[R], EffectFailure[E]](Ok(_Lease(rebind_var[R.Value](result^._take_ok()), release^))))


@fieldwise_init
struct _Join[L: _OpenScope, F: BorrowCallContract & Movable & Deinitable, pair: Bool](_OpenScope):
    var left: Self.L
    var function: Self.F
    comptime Right = downcast[Self.F.Result, _ResourceType].Recipe
    comptime Release = _PairRelease[Self.L.Release, Self.Right.Release] if Self.pair else _HoldRelease[Self.L.Release, Self.Right.Release]
    comptime Value = Self.Release.Value
    comptime Error = Self.Release.Error
    comptime Native = Self.L.Native and Self.Right.Native
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.Error]:
        comptime assert Self.Error == Self.L.Release.Error
        comptime assert Self.F.Payload == Self.L.Release.Value and _ErrorCompatible[Self.Error, Self.F.Failure]
        comptime assert Self.L.Release.Error == Self.Right.Release.Error
        comptime Output = Outcome[_Lease[Self.Release], Self.Error]
        var first = self.left^.open(context)
        if not first:
            return None
        var acquired = first.take()
        if acquired.is_err():
            return Optional(Result[_Lease[Self.Release], EffectFailure[Self.Error]](Err(rebind_var[EffectFailure[Self.Error]](acquired^._take_err()))))
        var left = acquired^._take_ok()
        if _scope_canceled[C, Self.Error](context):
            return left^.close(Output(), context)
        var made = _capture[Self.Error](_BorrowThunk(self.function^, Pointer(to=rebind[Self.F.Payload](left.value))))
        if made.is_err():
            var failed = Optional(Result[_Lease[Self.Release], EffectFailure[Self.Error]](Err(made^._take_err())))
            return left^.close(failed^, context)
        var recipe = rebind_var[downcast[Self.F.Result, _ResourceType]](made^._take_ok())._into_recipe()
        var second = recipe^.open(context)
        if not second:
            return left^.close(Output(), context)
        var next = second.take()
        if next.is_err():
            var failed = Optional(Result[_Lease[Self.Release], EffectFailure[Self.Error]](Err(rebind_var[EffectFailure[Self.Error]](next^._take_err()))))
            return left^.close(failed^, context)
        var right = next^._take_ok()
        comptime if Self.pair:
            return Optional(Result[_Lease[Self.Release], EffectFailure[Self.Error]](Ok(rebind_var[_Lease[Self.Release]](_pair_leases(left^, right^)))))
        else:
            return Optional(Result[_Lease[Self.Release], EffectFailure[Self.Error]](Ok(rebind_var[_Lease[Self.Release]](_hold_leases(left^, right^)))))


@fieldwise_init
struct Resource[O: _OpenScope](_ResourceType):
    """An inert, consumed recipe with explicitly sequenced acquisition and release.

    Build with resource, combine with product or flat_map, then consume with use.
    Acquisition occurs only in use. Every successfully acquired resource is
    released exactly once, in reverse order, even if use or a later acquisition
    fails. Unopened recipes only destroy their stored callback owners.

    Parameters:
        O: The concrete acquisition recipe, inferred by resource and composition.
    """
    var _recipe: Self.O
    comptime Recipe = Self.O
    """The concrete recipe type retained by this value."""
    comptime Value = Self.O.Release.Value
    """The acquired value borrowed by use and flat_map."""
    comptime Error = Self.O.Release.Error
    """The exact native error type collected by all callbacks in this scope."""

    def _into_recipe(deinit self) -> Self.O:
        return self._recipe^

    def use[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F
    ) -> Result[F.Result, EffectFailure[Self.Error]] where Self.O.Native and F.Payload == Self.Value and _ErrorCompatible[Self.Error, F.Failure] and _OnceBorrowAvailable[F]:
        """Acquire, borrow for use, and release, preserving every failure.

        Results and errors cannot borrow the acquired value. Move-only callback
        state is consumed once. A release result is discarded. If use succeeds
        but release fails, the unused success value is destroyed.

        Parameters:
            F: A borrowing callback with the exact acquired input type.

        Args:
            function: The use callback, consumed; skipped if acquisition fails.

        Returns:
            Ok of the owned result, or all exact errors in execution order.
        """
        var context: NoneType = None
        var opened = self._recipe^.open(context)
        var acquired = opened.take()
        if acquired.is_err():
            return Err(acquired^._take_err())
        var lease = acquired^._take_ok()
        var used = _capture[Self.Error](_BorrowThunk(function^, Pointer(to=rebind[F.Payload](lease.value))))
        var finalized = lease^.close(Optional(used^), context)
        return finalized.take()

    def use_void(deinit self) -> Result[NoneType, EffectFailure[Self.Error]] where Self.O.Native:
        """Acquire and release immediately, without a user-supplied body.

        Composed acquisitions and projections still run in order. Every
        registered release runs in reverse order, including after partial
        acquisition failure. The acquired values are never copied.

        Returns:
            Ok of None, or the existing ordered lifecycle failures.
        """
        var nothing: NoneType = None
        return self^.use(_IgnoreInput[Self.Value, _ValueThunk[NoneType]](_ValueThunk(nothing)))

    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[F, Self.Error], False]] where Self.O.Native and F.Payload == Self.Value and _ErrorCompatible[Self.Error, F.Failure] and _OnceBorrowAvailable[F]:
        """Project an owned value while retaining the original resource until release.

        This derives through flat_map and pure_resource. A failed projection
        releases the original resource; a successful projection is destroyed
        before that release. It cannot borrow the fresh acquired input origin.

        Parameters:
            F: The borrowing projection callback.

        Args:
            function: The projection, consumed and deferred until acquisition.

        Returns:
            A scope exposing F.Result and retaining the original finalizer.
        """
        return self^.flat_map(_MapScopeFactory[F, Self.Error](function^))

    def product[P: _OpenScope](deinit self, var right: Resource[P]
    ) -> Resource[_Join[Self.O, _ConstantResource[Self.Value, Resource[P]], True]] where Self.O.Native and P.Native and P.Release.Error == Self.Error:
        """Acquire both scopes left to right and expose their owned native pair.

        Parameters:
            P: The right acquisition recipe, inferred.

        Args:
            right: The right scope, consumed and still unopened.

        Returns:
            A scope of the pair, released right then left on every exit.
        """
        return Resource(_Join[Self.O, _ConstantResource[Self.Value, Resource[P]], True](self._recipe^, _ConstantResource[Self.Value, Resource[P]](right^)))

    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F
    ) -> Resource[_Join[Self.O, F, False]] where Self.O.Native and F.Payload == Self.Value and conforms_to(F.Result, _ResourceType) and downcast[F.Result, _ResourceType].Recipe.Native and _ErrorCompatible[Self.Error, F.Failure] and downcast[F.Result, _ResourceType].Recipe.Release.Error == Self.Error and _OnceBorrowAvailable[F]:
        """Derive an inner scope while retaining the outer resource until release.

        The factory borrows the outer value once. Its independent recipe cannot
        borrow that fresh input origin; no self-referential lease is constructed.
        Factory or inner acquisition failure still releases the outer value.

        Parameters:
            F: A borrowing factory returning a Resource of the same error type.

        Args:
            function: The deferred factory, consumed with this recipe.

        Returns:
            A scope exposing the inner value, released before its outer owner.
        """
        return Resource(_Join[Self.O, F, False](self._recipe^, function^))

    def use[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F
    ) -> Result[V, EffectFailure[Self.Error]] where Self.O.Native and P == Self.Value:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.use(_NativeBorrow[P, V, Never, F, False](function^))

    def use[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Result[V, EffectFailure[Self.Error]] where Self.O.Native and P == Self.Value and _ErrorCompatible[Self.Error, X]:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.use(_NativeBorrow[P, V, X, F, True](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _NativeBorrow[P, V, Never, F, False], False]] where Self.O.Native and P == Self.Value and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Native and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.flat_map(_NativeBorrow[P, V, Never, F, False](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _NativeBorrow[P, V, X, F, True], False]] where Self.O.Native and P == Self.Value and _ErrorCompatible[Self.Error, X] and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Native and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.flat_map(_NativeBorrow[P, V, X, F, True](function^))

    def map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, Never, F, False], Self.Error], False]] where Self.O.Native and P == Self.Value and _ErrorCompatible[Self.Error, Never]:
        """Adapt an owned native projection to the shared resource derivation."""
        return self^.map(_NativeBorrow[P, V, Never, F, False](function^))

    def map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, X, F, True], Self.Error], False]] where Self.O.Native and P == Self.Value and _ErrorCompatible[Self.Error, X]:
        """Adapt an owned native projection to the shared resource derivation."""
        return self^.map(_NativeBorrow[P, V, X, F, True](function^))


struct ResourceContract[A: ThunkContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable]:
    """Admission and exact recipe type for native resource construction.

    Use Out to name a resource returned by a deferred factory or generic wrapper.

    Parameters:
        A: The acquisition callback type.
        R: The consuming release callback type.
        E: The selected native error type.
    """
    comptime Compatible = Self.A.Out == Self.R.Arg and _ErrorCompatible[Self.E, Self.A.Error] and _ErrorCompatible[Self.E, Self.R.Error] and _OnceThunkAvailable[Self.A] and _OnceUnaryAvailable[Self.R]
    """Exact value identity, compatible errors and once-callable receivers."""
    comptime Out = Resource[_Acquire[Self.A, Self.R, Self.E]]
    """The concrete unopened Resource type, retaining every captured origin."""


def resource[A: ThunkContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](
    var acquire: A, var release: R
) -> Resource[_Acquire[A, R, E]] where A.Out == R.Arg and _ErrorCompatible[E, A.Error] and _ErrorCompatible[E, R.Error] and _OnceThunkAvailable[A] and _OnceUnaryAvailable[R]:
    """Describe a native resource without invoking acquisition or release.

    Select E explicitly. Each callback raises E or Never, and may be move-only.
    Release consumes the acquired value; its return value is discarded.

    Parameters:
        A: The acquisition thunk type, including its owned result.
        R: The consuming release callback type.
        E: The exact native error type shared by acquisition, use and release.

    Args:
        acquire: The acquisition thunk, moved into the recipe without calling it.
        release: The release callback, moved and called only after successful acquisition.

    Returns:
        An unopened resource recipe, consumed by use or further composition.
    """
    return Resource(_Acquire[A, R, E](acquire^, release^))


def resource[T: Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, A: _Thunk[T], R: _Unary[P, U]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, Never, A, False], NativeUnary[P, U, Never, R, False], E]] where T == P and _ErrorCompatible[E, Never] and _ErrorCompatible[E, Never]:
    """Own native acquisition and release callbacks without executing either."""
    return resource[E](_NativeThunk[T, Never, A, False](acquire^), NativeUnary[P, U, Never, R, False](release^))


def resource[T: Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, A: _Thunk[T], R: _RaisingUnary[P, U, Y]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, Never, A, False], NativeUnary[P, U, Y, R, True], E]] where T == P and _ErrorCompatible[E, Never] and _ErrorCompatible[E, Y]:
    """Own native acquisition and release callbacks without executing either."""
    return resource[E](_NativeThunk[T, Never, A, False](acquire^), NativeUnary[P, U, Y, R, True](release^))


def resource[T: Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, A: _RaisingThunk[T, X], R: _Unary[P, U]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, X, A, True], NativeUnary[P, U, Never, R, False], E]] where T == P and _ErrorCompatible[E, X] and _ErrorCompatible[E, Never]:
    """Own native acquisition and release callbacks without executing either."""
    return resource[E](_NativeThunk[T, X, A, True](acquire^), NativeUnary[P, U, Never, R, False](release^))


def resource[T: Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, A: _RaisingThunk[T, X], R: _RaisingUnary[P, U, Y]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, X, A, True], NativeUnary[P, U, Y, R, True], E]] where T == P and _ErrorCompatible[E, X] and _ErrorCompatible[E, Y]:
    """Own native acquisition and release callbacks without executing either."""
    return resource[E](_NativeThunk[T, X, A, True](acquire^), NativeUnary[P, U, Y, R, True](release^))


def resource[T: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable, A: _Thunk[T]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, Never, A, False], R, E]] where T == R.Arg and _ErrorCompatible[E, Never] and _ErrorCompatible[E, R.Error] and _OnceUnaryAvailable[R]:
    """Adapt native acquisition while retaining a library release receiver."""
    return resource[E](_NativeThunk[T, Never, A, False](acquire^), release^)


def resource[T: Movable & Deinitable, R: UnaryContract & Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, A: _RaisingThunk[T, X]](var acquire: A, var release: R
) -> Resource[_Acquire[_NativeThunk[T, X, A, True], R, E]] where T == R.Arg and _ErrorCompatible[E, X] and _ErrorCompatible[E, R.Error] and _OnceUnaryAvailable[R]:
    """Adapt native acquisition while retaining a library release receiver."""
    return resource[E](_NativeThunk[T, X, A, True](acquire^), release^)


def resource[A: ThunkContract & Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, R: _Unary[P, U]](var acquire: A, var release: R
) -> Resource[_Acquire[A, NativeUnary[P, U, Never, R, False], E]] where A.Out == P and _ErrorCompatible[E, A.Error] and _ErrorCompatible[E, Never] and _OnceThunkAvailable[A]:
    """Adapt native release while retaining a library acquisition receiver."""
    return resource[E](acquire^, NativeUnary[P, U, Never, R, False](release^))


def resource[A: ThunkContract & Movable & Deinitable, P: Movable & Deinitable, U: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable, R: _RaisingUnary[P, U, Y]](var acquire: A, var release: R
) -> Resource[_Acquire[A, NativeUnary[P, U, Y, R, True], E]] where A.Out == P and _ErrorCompatible[E, A.Error] and _ErrorCompatible[E, Y] and _OnceThunkAvailable[A]:
    """Adapt native release while retaining a library acquisition receiver."""
    return resource[E](acquire^, NativeUnary[P, U, Y, R, True](release^))


def pure_resource[T: Movable & Deinitable, //, E: Movable & Deinitable](var value: T) -> Resource[_PureResource[T, E]]:
    """Own a value in a resource recipe with ordinary native destruction.

    No acquire or release callback is added. An unopened recipe destroys the
    value normally; an opened recipe holds it until use finishes. Resource.map
    uses this adapter to retain the original scope through flat_map.

    Parameters:
        T: The owned value type, including embedded origins.
        E: The resource error family selected for subsequent composition.

    Args:
        value: The already-created value, consumed into the recipe.

    Returns:
        An unopened scope whose only release action is native value destruction.
    """
    return Resource(_PureResource[T, E](value^))
