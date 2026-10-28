"""Consumed native resource recipes with explicit, composable finalization."""
from std.builtin.rebind import downcast, rebind_var
from std.memory import MaybeUninit
from fp.callables.protocols import ThunkContract, UnaryContract, BorrowCallContract, BorrowOnceCallable
from fp.callables.invoke import _OnceThunkAvailable, _OnceUnaryAvailable
from fp.callables._receiver import _OnceBorrowAvailable, _borrow_once_as
from fp.callables._binding import _OwnedThunk, _OwnedUnary, _BorrowThunk
from fp.callables.products import _take_pair
from fp.callables.native import _NativeThunk, NativeUnary, _NativeBorrow, _Thunk, _RaisingThunk, _Unary, _RaisingUnary, _Borrowing, _RaisingBorrowing
from fp.data import Result, Ok, Err
from fp._internal.errors import _ErrorCompatible
from .outcomes import EffectFailure, _capture, _discard, _finish_native


trait _Releaser(Movable, Deinitable):
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def release(deinit self, var value: Self.Value) -> Result[NoneType, EffectFailure[Self.Error]]:
        ...


@fieldwise_init
struct _Lease[R: _Releaser](Movable):
    var value: Self.R.Value
    var releaser: Self.R
    def close(deinit self) -> Result[NoneType, EffectFailure[Self.R.Error]]:
        return self.releaser^.release(self.value^)
    def into_parts(deinit self) -> Tuple[Self.R.Value, Self.R]:
        return (self.value^, self.releaser^)


trait _OpenScope(Movable, Deinitable):
    comptime Release: _Releaser
    def open(deinit self) -> Result[_Lease[Self.Release], EffectFailure[Self.Release.Error]]:
        ...


@fieldwise_init
struct _DropResource[T: Movable & Deinitable, E: Movable & Deinitable](_Releaser):
    comptime Value = Self.T
    comptime Error = Self.E
    def release(deinit self, var value: Self.Value) -> Result[NoneType, EffectFailure[Self.Error]]:
        var unit: NoneType = None
        return Ok(unit)


@fieldwise_init
struct _PureResource[T: Movable & Deinitable, E: Movable & Deinitable](_OpenScope):
    var value: Self.T
    comptime Release = _DropResource[Self.T, Self.E]
    def open(deinit self) -> Result[_Lease[Self.Release], EffectFailure[Self.E]]:
        return Ok(_Lease[Self.Release](self.value^, Self.Release()))


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
    def release(deinit self, var value: Self.Value) -> Result[NoneType, EffectFailure[Self.Error]]:
        comptime assert _ErrorCompatible[Self.E, Self.R.Error]
        return _discard(_capture[Self.E](_OwnedUnary(self.function^, value^)))


@fieldwise_init
struct _Acquire[A: ThunkContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](_OpenScope):
    var acquire: Self.A
    var release: Self.R
    comptime Release = _NativeRelease[Self.R, Self.E]
    comptime Value = Self.Release.Value
    comptime Error = Self.Release.Error
    def open(deinit self) -> Result[_Lease[Self.Release], EffectFailure[Self.Error]]:
        comptime assert Self.A.Out == Self.R.Arg and _ErrorCompatible[Self.E, Self.A.Error]
        var acquired = _capture[Self.E](_OwnedThunk(self.acquire^))
        if acquired.is_err():
            return Err(acquired^._take_err())
        return Ok(_Lease[Self.Release](rebind_var[Self.Value](acquired^._take_ok()), Self.Release(self.release^)))


def _close_two[L: _Releaser, R: _Releaser](var left: _Lease[L], var right: _Lease[R]
) -> Result[NoneType, EffectFailure[L.Error]]:
    comptime assert L.Error == R.Error
    var closed_right = right^.close()
    var closed_left = left^.close()
    return _finish_native(rebind_var[Result[NoneType, EffectFailure[L.Error]]](closed_right^), closed_left^)


@fieldwise_init
struct _PairRelease[L: _Releaser, R: _Releaser](_Releaser):
    var left: Self.L
    var right: Self.R
    comptime Value = Tuple[Self.L.Value, Self.R.Value]
    comptime Error = Self.L.Error
    def release(deinit self, var value: Self.Value) -> Result[NoneType, EffectFailure[Self.Error]]:
        var left_slot = MaybeUninit[Self.L.Value]()
        var right_slot = MaybeUninit[Self.R.Value]()
        _take_pair(value^, left_slot, right_slot)
        var left = _Lease(left_slot^.unsafe_assume_init(), self.left^)
        var right = _Lease(right_slot^.unsafe_assume_init(), self.right^)
        return _close_two(left^, right^)


@fieldwise_init
struct _HoldRelease[L: _Releaser, R: _Releaser](_Releaser):
    var left: _Lease[Self.L]
    var right: Self.R
    comptime Value = Self.R.Value
    comptime Error = Self.L.Error
    def release(deinit self, var value: Self.Value) -> Result[NoneType, EffectFailure[Self.Error]]:
        return _close_two(self.left^, _Lease(value^, self.right^))


def _pair_leases[L: _Releaser, R: _Releaser](var left: _Lease[L], var right: _Lease[R]) -> _Lease[_PairRelease[L, R]]:
    var left_value = MaybeUninit[L.Value]()
    var left_release = MaybeUninit[L]()
    var right_value = MaybeUninit[R.Value]()
    var right_release = MaybeUninit[R]()
    _take_pair(left^.into_parts(), left_value, left_release)
    _take_pair(right^.into_parts(), right_value, right_release)
    return _Lease[_PairRelease[L, R]]((left_value^.unsafe_assume_init(), right_value^.unsafe_assume_init()), _PairRelease(left_release^.unsafe_assume_init(), right_release^.unsafe_assume_init()))


@fieldwise_init
struct _ConstantResource[T: AnyType, R: _OpenScope](BorrowOnceCallable):
    var right: Resource[Self.R]
    comptime Payload = Self.T
    comptime Result = Resource[Self.R]
    def invoke_once(deinit self, ref value: Self.Payload) -> Self.Result:
        return self.right^


@fieldwise_init
struct _Join[L: _OpenScope, F: BorrowCallContract & Movable & Deinitable, pair: Bool](_OpenScope):
    var left: Self.L
    var function: Self.F
    comptime Right = downcast[Self.F.Result, _ResourceType].Recipe
    comptime Release = _PairRelease[Self.L.Release, Self.Right.Release] if Self.pair else _HoldRelease[Self.L.Release, Self.Right.Release]
    comptime Value = Self.Release.Value
    comptime Error = Self.Release.Error
    def open(deinit self) -> Result[_Lease[Self.Release], EffectFailure[Self.Error]]:
        comptime assert Self.Error == Self.L.Release.Error
        comptime assert Self.F.Payload == Self.L.Release.Value and _ErrorCompatible[Self.Error, Self.F.Failure]
        comptime assert Self.L.Release.Error == Self.Right.Release.Error
        comptime Output = Result[_Lease[Self.Release], EffectFailure[Self.Error]]
        var first = self.left^.open()
        if first.is_err():
            return Err(rebind_var[EffectFailure[Self.Error]](first^._take_err()))
        var left = first^._take_ok()
        var made = _capture[Self.Error](_BorrowThunk(self.function^, Pointer(to=rebind[Self.F.Payload](left.value))))
        if made.is_err():
            return _finish_native(Output(Err(made^._take_err())), rebind_var[Result[NoneType, EffectFailure[Self.Error]]](left^.close()))
        var recipe = rebind_var[downcast[Self.F.Result, _ResourceType]](made^._take_ok())._into_recipe()
        var second = recipe^.open()
        if second.is_err():
            return _finish_native(Output(Err(rebind_var[EffectFailure[Self.Error]](second^._take_err()))), rebind_var[Result[NoneType, EffectFailure[Self.Error]]](left^.close()))
        var right = second^._take_ok()
        comptime if Self.pair:
            return Ok(rebind_var[_Lease[Self.Release]](_pair_leases(left^, right^)))
        else:
            var value_slot = MaybeUninit[Self.Right.Release.Value]()
            var release_slot = MaybeUninit[Self.Right.Release]()
            _take_pair(right^.into_parts(), value_slot, release_slot)
            return Ok(_Lease[Self.Release](rebind_var[Self.Value](value_slot^.unsafe_assume_init()), rebind_var[Self.Release](_HoldRelease(left^, release_slot^.unsafe_assume_init()))))


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
    ) -> Result[F.Result, EffectFailure[Self.Error]] where F.Payload == Self.Value and _ErrorCompatible[Self.Error, F.Failure] and _OnceBorrowAvailable[F]:
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
        var acquired = self._recipe^.open()
        if acquired.is_err():
            return Err(acquired^._take_err())
        var lease = acquired^._take_ok()
        var used = _capture[Self.Error](_BorrowThunk(function^, Pointer(to=rebind[F.Payload](lease.value))))
        var released = lease^.close()
        return _finish_native(used^, released^)

    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[F, Self.Error], False]] where F.Payload == Self.Value and _ErrorCompatible[Self.Error, F.Failure] and _OnceBorrowAvailable[F]:
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
    ) -> Resource[_Join[Self.O, _ConstantResource[Self.Value, P], True]] where P.Release.Error == Self.Error:
        """Acquire both scopes left to right and expose their owned native pair.

        Parameters:
            P: The right acquisition recipe, inferred.

        Args:
            right: The right scope, consumed and still unopened.

        Returns:
            A scope of the pair, released right then left on every exit.
        """
        return Resource(_Join[Self.O, _ConstantResource[Self.Value, P], True](self._recipe^, _ConstantResource[Self.Value, P](right^)))

    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var function: F
    ) -> Resource[_Join[Self.O, F, False]] where F.Payload == Self.Value and conforms_to(F.Result, _ResourceType) and _ErrorCompatible[Self.Error, F.Failure] and downcast[F.Result, _ResourceType].Recipe.Release.Error == Self.Error and _OnceBorrowAvailable[F]:
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
    ) -> Result[V, EffectFailure[Self.Error]] where P == Self.Value:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.use(_NativeBorrow[P, V, Never, F, False](function^))

    def use[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Result[V, EffectFailure[Self.Error]] where P == Self.Value and _ErrorCompatible[Self.Error, X]:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.use(_NativeBorrow[P, V, X, F, True](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _NativeBorrow[P, V, Never, F, False], False]] where P == Self.Value and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.flat_map(_NativeBorrow[P, V, Never, F, False](function^))

    def flat_map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _NativeBorrow[P, V, X, F, True], False]] where P == Self.Value and _ErrorCompatible[Self.Error, X] and conforms_to(V, _ResourceType) and downcast[V, _ResourceType].Recipe.Release.Error == Self.Error:
        """Adapt an owned native borrowing callback to the shared scope runner."""
        return self^.flat_map(_NativeBorrow[P, V, X, F, True](function^))

    def map[P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, Never, F, False], Self.Error], False]] where P == Self.Value and _ErrorCompatible[Self.Error, Never]:
        """Adapt an owned native projection to the shared resource derivation."""
        return self^.map(_NativeBorrow[P, V, Never, F, False](function^))

    def map[P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](deinit self, var function: F
    ) -> Resource[_Join[Self.O, _MapScopeFactory[_NativeBorrow[P, V, X, F, True], Self.Error], False]] where P == Self.Value and _ErrorCompatible[Self.Error, X]:
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
