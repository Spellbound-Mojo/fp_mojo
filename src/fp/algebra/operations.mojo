"""Public algebra operations: the instance is explicit, operands are inferred.

Entries use the instance's primitive or its associated pure constructor. The
carrier comes first and the callback last, as in Cats' `Functor[F].map(fa)(f)`.
`map`, `flat_map` and `traverse` also accept native functions and closures
directly, for every instance: plain functions are copied, closures borrowed.
Generic code that forwards a raising native closure names its error type with
`X=`.
"""
from fp.algebra._admission import _MapCompatible, _BindCompatible, _CombineCompatible, _CollectCompatible
from std.builtin.rebind import rebind_var, downcast
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, _ErrorProbe
from fp.callables.native import NativeUnary, _NativeUnaryRef, _NativeOwnedArg
from fp._internal.errors import _ErrorCompatible
from .protocols import _SemigroupBinary
from .protocols import Functor, Applicative, Monad, Traversable, Monoid, Semigroup, _pure, _map_as, _flat_map_as, _traverse_as
from ._contracts import MapContract, BindContract, TraverseContract, FilterContract, CombineContract
from .collections import _SourceFamily, _UnrecognizedCarrier
from .instances import _InferredApplicative, _ViewTarget


def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor]](var value: V, var f: F
) raises MapContract[I, V, F].Error -> MapContract[I, V, F].Out where MapContract[I, V, F].Compatible:
    """Apply `f` to the payload of `value`, keeping the carrier's context: the `Functor` operation.

    Other overloads take a native function or closure directly, for every
    instance: `map(value^, twice)`. A plain function is
    copied, so a deferred computation such as `IO` can keep it. A closure is
    borrowed, not moved: an eager instance calls it before returning, and a
    deferred computation keeps the borrow until it runs, so keep the closure
    alive and unmoved until then, or move it in with `as_unary(f^)`. Its parameter type must
    equal the carrier's element type, origins included. Generic code that
    forwards a raising native callback names its error with `X=`.

    Parameters:
        V: The carrier's type.
        F: The callback's type: a library `Unary` value in any receiver mode.
        I: The instance, such as `OptionalFamily` or `ReaderT[M, R]`; defaults to the carrier's family.

    Args:
        value: The carrier, consumed.
        f: The callback, consumed.

    Returns:
        The carrier of the callback's results, `I.Mapped[V, F]`.

    Raises:
        `I.MapError[V, F]`: the callback's error, unchanged.
    """
    return I.map(f^, value^)


def pure[A: Movable & Deinitable, //, I: Applicative](var value: A) -> I.Pure[A]:
    """Introduce a value in the instance's neutral context: the `Applicative` unit.

    Parameters:
        A: The value's type.
        I: The instance.

    Args:
        value: The value, consumed.

    Returns:
        `I.Pure[A]`, the carrier holding `value`.
    """
    return _pure[I](value^)


def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, //,
              I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](var left: V, var right: R, var f: F) raises CombineContract[I, V, F, R].Error -> CombineContract[I, V, F, R].Out where CombineContract[I, V, F, R].OperationCompatible:
    """Combine the payload of `left` with that of the carrier `right` produces.

    `right` runs at most once per combination, and not at all when `left`
    already determines failure or emptiness. A produced right value is kept for
    later branches; a list combines in left-major Cartesian order.

    Parameters:
        V: The left carrier's type.
        F: The combiner's type: a library `Binary` value.
        R: The right operand's type: a library `Thunk` value producing a carrier.
        I: The instance; defaults to the left carrier's family.

    Args:
        left: The left carrier, consumed.
        right: The thunk producing the right carrier, consumed.
        f: The combiner, consumed.

    Returns:
        `I.Combined[V, F, R]`, the carrier of the combined payloads.

    Raises:
        `I.CombineError[V, F, R]`: the combiner's or the thunk's error.
    """
    return I.map2_lazy(f^, left^, right^)


def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var value: V, var f: F
) raises BindContract[I, V, F].Error -> BindContract[I, V, F].Out where BindContract[I, V, F].Compatible:
    """Let `f` choose the next carrier of the same family from the payload of `value`: the `Monad` operation.

    An absent `Optional`, a failed `Result` or an empty `List` skips the
    callback.

    Other overloads take a native function or closure directly, for every
    instance: `flat_map(value^, halve)`. A plain function is
    copied, so a deferred computation such as `IO` can keep it. A closure is
    borrowed, not moved: an eager instance calls it before returning, and a
    deferred computation keeps the borrow until it runs, so keep the closure
    alive and unmoved until then, or move it in with `as_unary(f^)`. Its parameter type must
    equal the carrier's element type, origins included. Generic code that
    forwards a raising native callback names its error with `X=`.

    Parameters:
        V: The carrier's type.
        F: The callback's type: a library `Unary` value returning a carrier of the same family.
        I: The instance; defaults to the carrier's family.

    Args:
        value: The carrier, consumed.
        f: The callback, consumed.

    Returns:
        `I.Bound[V, F]`, the carrier the callback returned.

    Raises:
        `I.BindError[V, F]`: the callback's error, unchanged.
    """
    return I.flat_map(f^, value^)


def traverse[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[F.Out], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](
    var source: V, var f: F
) raises TraverseContract[S, G, V, F].Error -> TraverseContract[S, G, V, F].Out where TraverseContract[S, G, V, F].InputCompatible and TraverseContract[S, G, V, F].TargetCompatible:
    """Call an effectful `f` on each element of `source`, in order, and gather the results in one `G` carrier.

    The source keeps its shape. Once `G` has failed (an absent `Optional`, a
    failed `Result`), no further element is pulled and the callback is not
    called again. A `List` source is gathered by `G.collect`; any owned
    iterable or iterator can be the source. Other overloads take a native
    function (copied) or closure (borrowed) directly.

    Parameters:
        V: The source's type.
        F: The callback's type: a repeatable library `Unary` value returning a `G` carrier.
        G: The callback's applicative instance, such as `ResultFamily[E]`; defaults to the family of the callback's result.
        S: The source's instance, such as `ListFamily`; defaults to the source's family.

    Args:
        source: The source, consumed.
        f: The callback, consumed.

    Returns:
        `S.Traversed[G, V, F]`, `G`'s carrier of the results in source shape.

    Raises:
        `S.TraverseError[G, V, F]`: the callback's error, and any error `G` adds.
    """
    return S.traverse[G](f^, source^)


def empty[M: Monoid]() raises M.Error -> M.Value:
    """The monoid's identity element.

    Parameters:
        M: The monoid, such as `StringMonoid`.

    Returns:
        `M.empty()`.

    Raises:
        `M.Error`; nothing for the library's monoids.
    """
    return M.empty()


def combine[M: Semigroup](var left: M.Value, var right: M.Value) raises M.Error -> M.Value:
    """Combine two values with an associative, ordered Semigroup.

    Parameters:
        M: The Semigroup or Monoid.

    Args:
        left: The first value, consumed.
        right: The second value, consumed.

    Returns:
        `M.combine(left, right)`.

    Raises:
        `M.Error`; nothing for the library's monoids.
    """
    return _SemigroupBinary[M]().call(left^, right^)


# Generic code that forwards a raising native closure names its error with X=,
# which must equal the callback's error.
struct _InferError(Movable where False):
    pass


comptime _EntryError[Expected: AnyType, Actual: Movable & Deinitable]: Movable & Deinitable = (
    downcast[Expected, Movable & Deinitable] if conforms_to(Expected, Movable & Deinitable) else Actual
)


def _map_native[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable,
                E: Movable & Deinitable, I: Functor, F: Movable & Deinitable, raising: Bool,
                o: ImmOrigin, Raised: Movable & Deinitable = I.MapError[V, _ErrorProbe[A, R, E]]](
    ref[o] f: F, var value: V
) raises Raised -> I.Mapped[V, _NativeUnaryRef[A, R, E, F, raising, o]]:
    # Native admission belongs to the public signatures. This shared bridge
    # also serves Piped, whose forwarded F.A/F.R/F.E evidence Mojo 1.1 cannot
    # equate with A/R/E inside a generic family's associated error alias.
    comptime D = _NativeUnaryRef[A, R, E, F, raising, o]
    comptime assert I.MapError[V, D] == I.MapError[V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, D]]
    return _map_as[Raised, I](D(Pointer(to=f)), value^)


# Native functions and closures for every instance, generated from the callback
# catalog: closures are borrowed in place, plain functions are copied into an
# owned NativeUnary so deferred families such as IO can keep them.
# --- native algebra admission (generated) ---
def map[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor]](var value: V, ref[o] function: F) raises I.MapError[V, F._View[o]] -> I.Mapped[V, F._View[o]] where _MapCompatible[I, V, F._View[o]]:
    """Admit a view callback; execution stays with the family."""
    comptime Raised = I.MapError[V, F._View[o]]
    comptime assert I.MapError[V, F._View[o]] == I.MapError[V, F._View[o]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, F._View[o]]]
    return _map_as[Raised, I](function._unary_view(), value^)


@always_inline
def map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor], F: def(var A) -> R = def(var A) -> R](var value: V, ref[o] function: F) raises I.MapError[V, _ErrorProbe[A, R, Never]] -> I.Mapped[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A and _MapCompatible[I, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Admit a closure callback; execution stays with the family."""
    comptime Raised = I.MapError[V, _ErrorProbe[A, R, Never]]
    comptime assert I.MapError[V, _NativeUnaryRef[A, R, Never, F, False, o]] == I.MapError[V, _ErrorProbe[A, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, _NativeUnaryRef[A, R, Never, F, False, o]]]
    return _map_as[Raised, I](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), value^)


@always_inline
def map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](var value: V, ref[o] function: F) raises _EntryError[X, I.MapError[V, _ErrorProbe[A, R, E]]] -> I.Mapped[V, _NativeUnaryRef[A, R, E, F, True, o]] where I.Element[V] == A and _MapCompatible[I, V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E):
    """Admit a closure callback that raises; execution stays with the family."""
    comptime Raised = _EntryError[X, I.MapError[V, _ErrorProbe[A, R, E]]]
    comptime assert I.MapError[V, _NativeUnaryRef[A, R, E, F, True, o]] == I.MapError[V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, _NativeUnaryRef[A, R, E, F, True, o]]]
    return _map_as[Raised, I](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), value^)


def map[V: Movable & Deinitable, R: Movable & Deinitable, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) thin -> R) raises I.MapError[V, _ErrorProbe[NoneType, R, Never]] -> I.Mapped[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and _MapCompatible[I, V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = I.MapError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert I.MapError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] == I.MapError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]]
    return _map_as[Raised, I](NativeUnary[I.Element[V], R, Never, type_of(function), False](function), value^)


def map[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) thin -> R) raises I.MapError[V, _ErrorProbe[NoneType, R, Never]] -> I.Mapped[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] where _MapCompatible[I, V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = I.MapError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert I.MapError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] == I.MapError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]]
    return _map_as[Raised, I](NativeUnary[I.Element[V], R, Never, type_of(function), False](function), value^)


def map[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Functor) else _UnrecognizedCarrier, Functor]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) raises E thin -> R) raises I.MapError[V, _ErrorProbe[NoneType, R, E]] -> I.Mapped[V, NativeUnary[I.Element[V], R, E, type_of(function), True]] where _MapCompatible[I, V, NativeUnary[I.Element[V], R, E, type_of(function), True]]:
    """Admit a thin callback that raises; execution stays with the family."""
    comptime Raised = I.MapError[V, _ErrorProbe[NoneType, R, E]]
    comptime assert I.MapError[V, NativeUnary[I.Element[V], R, E, type_of(function), True]] == I.MapError[V, _ErrorProbe[NoneType, R, E]]
    comptime assert _ErrorCompatible[Raised, I.MapError[V, NativeUnary[I.Element[V], R, E, type_of(function), True]]]
    return _map_as[Raised, I](NativeUnary[I.Element[V], R, E, type_of(function), True](function), value^)


def flat_map[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var value: V, ref[o] function: F) raises I.BindError[V, F._View[o]] -> I.Bound[V, F._View[o]] where _BindCompatible[I, V, F._View[o]]:
    """Admit a view callback; execution stays with the family."""
    comptime Raised = I.BindError[V, F._View[o]]
    comptime assert I.BindError[V, F._View[o]] == I.BindError[V, F._View[o]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, F._View[o]]]
    return _flat_map_as[Raised, I](function._unary_view(), value^)


@always_inline
def flat_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad], F: def(var A) -> R = def(var A) -> R](var value: V, ref[o] function: F) raises I.BindError[V, _ErrorProbe[A, R, Never]] -> I.Bound[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A and _BindCompatible[I, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Admit a closure callback; execution stays with the family."""
    comptime Raised = I.BindError[V, _ErrorProbe[A, R, Never]]
    comptime assert I.BindError[V, _NativeUnaryRef[A, R, Never, F, False, o]] == I.BindError[V, _ErrorProbe[A, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, _NativeUnaryRef[A, R, Never, F, False, o]]]
    return _flat_map_as[Raised, I](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), value^)


@always_inline
def flat_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](var value: V, ref[o] function: F) raises _EntryError[X, I.BindError[V, _ErrorProbe[A, R, E]]] -> I.Bound[V, _NativeUnaryRef[A, R, E, F, True, o]] where I.Element[V] == A and _BindCompatible[I, V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E):
    """Admit a closure callback that raises; execution stays with the family."""
    comptime Raised = _EntryError[X, I.BindError[V, _ErrorProbe[A, R, E]]]
    comptime assert I.BindError[V, _NativeUnaryRef[A, R, E, F, True, o]] == I.BindError[V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, _NativeUnaryRef[A, R, E, F, True, o]]]
    return _flat_map_as[Raised, I](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), value^)


def flat_map[V: Movable & Deinitable, R: Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) thin -> R) raises I.BindError[V, _ErrorProbe[NoneType, R, Never]] -> I.Bound[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and _BindCompatible[I, V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = I.BindError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert I.BindError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] == I.BindError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]]
    return _flat_map_as[Raised, I](NativeUnary[I.Element[V], R, Never, type_of(function), False](function), value^)


def flat_map[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) thin -> R) raises I.BindError[V, _ErrorProbe[NoneType, R, Never]] -> I.Bound[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] where _BindCompatible[I, V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = I.BindError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert I.BindError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]] == I.BindError[V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, NativeUnary[I.Element[V], R, Never, type_of(function), False]]]
    return _flat_map_as[Raised, I](NativeUnary[I.Element[V], R, Never, type_of(function), False](function), value^)


def flat_map[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var value: V, function: def(var _NativeOwnedArg[I.Element[V]]) raises E thin -> R) raises I.BindError[V, _ErrorProbe[NoneType, R, E]] -> I.Bound[V, NativeUnary[I.Element[V], R, E, type_of(function), True]] where _BindCompatible[I, V, NativeUnary[I.Element[V], R, E, type_of(function), True]]:
    """Admit a thin callback that raises; execution stays with the family."""
    comptime Raised = I.BindError[V, _ErrorProbe[NoneType, R, E]]
    comptime assert I.BindError[V, NativeUnary[I.Element[V], R, E, type_of(function), True]] == I.BindError[V, _ErrorProbe[NoneType, R, E]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, NativeUnary[I.Element[V], R, E, type_of(function), True]]]
    return _flat_map_as[Raised, I](NativeUnary[I.Element[V], R, E, type_of(function), True](function), value^)


def traverse[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, G: Applicative = _ViewTarget[F, o], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, ref[o] function: F) raises S.TraverseError[G, V, F._View[o]] -> S.Traversed[G, V, F._View[o]] where S.TargetCompatible[G, V, F._View[o]]:
    """Admit a view callback; execution stays with the family."""
    comptime Raised = S.TraverseError[G, V, F._View[o]]
    comptime assert S.TraverseError[G, V, F._View[o]] == S.TraverseError[G, V, F._View[o]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, F._View[o]]]
    return _traverse_as[S, G, V, F._View[o], Raised](function._unary_view(), source^)


@always_inline
def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable], F: def(var A) -> R = def(var A) -> R](var source: V, ref[o] function: F) raises S.TraverseError[G, V, _ErrorProbe[A, R, Never]] -> S.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]] where S.Element[V] == A and S.TargetCompatible[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Admit a closure callback; execution stays with the family."""
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[A, R, Never]]
    comptime assert S.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]] == S.TraverseError[G, V, _ErrorProbe[A, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]
    return _traverse_as[S, G, V, _NativeUnaryRef[A, R, Never, F, False, o], Raised](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)


@always_inline
def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](var source: V, ref[o] function: F) raises _EntryError[X, S.TraverseError[G, V, _ErrorProbe[A, R, E]]] -> S.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]] where S.Element[V] == A and S.TargetCompatible[G, V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E):
    """Admit a closure callback that raises; execution stays with the family."""
    comptime Raised = _EntryError[X, S.TraverseError[G, V, _ErrorProbe[A, R, E]]]
    comptime assert S.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]] == S.TraverseError[G, V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]
    return _traverse_as[S, G, V, _NativeUnaryRef[A, R, E, F, True, o], Raised](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)


def traverse[V: Movable & Deinitable, R: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) thin -> R) raises S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]] -> S.Traversed[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and S.TargetCompatible[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]]
    comptime assert S.TraverseError[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] == S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]]
    return _traverse_as[S, G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False], Raised](NativeUnary[S.Element[V], R, Never, type_of(function), False](function), source^)


def traverse[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, G: Applicative = _InferredApplicative[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) thin -> R) raises S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]] -> S.Traversed[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] where S.TargetCompatible[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]]
    comptime assert S.TraverseError[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] == S.TraverseError[G, V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]]
    return _traverse_as[S, G, V, NativeUnary[S.Element[V], R, Never, type_of(function), False], Raised](NativeUnary[S.Element[V], R, Never, type_of(function), False](function), source^)


def traverse[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) raises E thin -> R) raises S.TraverseError[G, V, _ErrorProbe[NoneType, R, E]] -> S.Traversed[G, V, NativeUnary[S.Element[V], R, E, type_of(function), True]] where S.TargetCompatible[G, V, NativeUnary[S.Element[V], R, E, type_of(function), True]]:
    """Admit a thin callback that raises; execution stays with the family."""
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[NoneType, R, E]]
    comptime assert S.TraverseError[G, V, NativeUnary[S.Element[V], R, E, type_of(function), True]] == S.TraverseError[G, V, _ErrorProbe[NoneType, R, E]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[G, V, NativeUnary[S.Element[V], R, E, type_of(function), True]]]
    return _traverse_as[S, G, V, NativeUnary[S.Element[V], R, E, type_of(function), True], Raised](NativeUnary[S.Element[V], R, E, type_of(function), True](function), source^)


# --- end native algebra admission ---
