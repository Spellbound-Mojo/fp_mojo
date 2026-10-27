"""Public algebra operations: the instance is explicit, operands are inferred.

Entries use the instance's primitive or its associated pure constructor. `map`, `flat_map` and
`traverse` also accept native functions and closures directly, for every
instance; generic code that forwards a raising native callback names its error
type with `X=`.
"""
from fp.algebra._admission import _MapCompatible, _BindCompatible, _CombineCompatible, _CollectCompatible
from std.builtin.rebind import rebind_var, downcast
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp.callables.native import _NativeUnaryRef, _Unary, _RaisingUnary
from fp._internal.errors import _ErrorCompatible
from .protocols import Functor, Applicative, Monad, Traversable, Monoid, Semigroup, _pure, _map_as, _flat_map_as, _traverse_as
from .contracts import MapContract, BindContract, TraverseContract, FilterContract, CombineContract


def map[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Functor](
    ref[o] f: F, var value: V
) raises MapContract[I, V, F._View[o]].Error -> MapContract[I, V, F._View[o]].Out where MapContract[I, V, F._View[o]].Compatible:
    """Borrow an origin-dependent callable through its internal shared view."""
    return map[I](f._unary_view(), value^)


def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Functor](var f: F, var value: V
) raises MapContract[I, V, F].Error -> MapContract[I, V, F].Out where MapContract[I, V, F].Compatible:
    """Apply `f` to the payload of `value`, keeping the carrier's context: the `Functor` operation.

    Another overload takes a native function or closure directly, for every
    instance: `map[OptionalFamily](twice, value^)`. It is borrowed, not moved:
    an eager instance calls it before returning, and a deferred computation
    keeps the borrow until it runs, so keep the callback alive and unmoved
    until then, or move it in with `as_unary(f^)`. Its parameter type must
    equal the carrier's element type, origins included. Generic code that
    forwards a raising native callback names its error with `X=`.

    Parameters:
        V: The carrier's type.
        F: The callback's type: a library `Unary` value in any receiver mode.
        I: The instance, such as `OptionalFamily` or `ReaderT[M, R]`.

    Args:
        f: The callback, consumed.
        value: The carrier, consumed.

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
              I: Applicative](var f: F, var left: V, var right: R) raises CombineContract[I, V, F, R].Error -> CombineContract[I, V, F, R].Out where CombineContract[I, V, F, R].OperationCompatible:
    """Combine the payload of `left` with that of the carrier `right` produces.

    `right` runs at most once per combination, and not at all when `left`
    already determines failure or emptiness. A produced right value is kept for
    later branches; a list combines in left-major Cartesian order.

    Parameters:
        V: The left carrier's type.
        F: The combiner's type: a library `Binary` value.
        R: The right operand's type: a library `Thunk` value producing a carrier.
        I: The instance.

    Args:
        f: The combiner, consumed.
        left: The left carrier, consumed.
        right: The thunk producing the right carrier, consumed.

    Returns:
        `I.Combined[V, F, R]`, the carrier of the combined payloads.

    Raises:
        `I.CombineError[V, F, R]`: the combiner's or the thunk's error.
    """
    return I.map2_lazy(f^, left^, right^)


def flat_map[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Monad](
    ref[o] f: F, var value: V
) raises BindContract[I, V, F._View[o]].Error -> BindContract[I, V, F._View[o]].Out where BindContract[I, V, F._View[o]].Compatible:
    """Borrow an origin-dependent callable through its internal shared view."""
    return flat_map[I](f._unary_view(), value^)


def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Monad](var f: F, var value: V
) raises BindContract[I, V, F].Error -> BindContract[I, V, F].Out where BindContract[I, V, F].Compatible:
    """Let `f` choose the next carrier of the same family from the payload of `value`: the `Monad` operation.

    An absent `Optional`, a failed `Result` or an empty `List` skips the
    callback.

    Another overload takes a native function or closure directly, for every
    instance: `flat_map[OptionalFamily](halve, value^)`. It is borrowed, not moved:
    an eager instance calls it before returning, and a deferred computation
    keeps the borrow until it runs, so keep the callback alive and unmoved
    until then, or move it in with `as_unary(f^)`. Its parameter type must
    equal the carrier's element type, origins included. Generic code that
    forwards a raising native callback names its error with `X=`.

    Parameters:
        V: The carrier's type.
        F: The callback's type: a library `Unary` value returning a carrier of the same family.
        I: The instance.

    Args:
        f: The callback, consumed.
        value: The carrier, consumed.

    Returns:
        `I.Bound[V, F]`, the carrier the callback returned.

    Raises:
        `I.BindError[V, F]`: the callback's error, unchanged.
    """
    return I.flat_map(f^, value^)


def traverse[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, S: Traversable, G: Applicative](
    ref[o] f: F, var source: V
) raises TraverseContract[S, G, V, F._View[o]].Error -> TraverseContract[S, G, V, F._View[o]].Out where TraverseContract[S, G, V, F._View[o]].InputCompatible and TraverseContract[S, G, V, F._View[o]].TargetCompatible:
    """Borrow an origin-dependent callable through its internal shared view."""
    return traverse[S, G](f._unary_view(), source^)


def traverse[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, S: Traversable, G: Applicative](
    var f: F, var source: V
) raises TraverseContract[S, G, V, F].Error -> TraverseContract[S, G, V, F].Out where TraverseContract[S, G, V, F].InputCompatible and TraverseContract[S, G, V, F].TargetCompatible:
    """Call an effectful `f` on each element of `source`, in order, and gather the results in one `G` carrier.

    The source keeps its shape. Once `G` has failed (an absent `Optional`, a
    failed `Result`), no further element is pulled and the callback is not
    called again. A `List` source is gathered by `G.collect`; any owned
    iterable or iterator can be the source. Another overload takes a native
    function or closure directly.

    Parameters:
        V: The source's type.
        F: The callback's type: a repeatable library `Unary` value returning a `G` carrier.
        S: The source's instance, such as `ListFamily`.
        G: The callback's applicative instance, such as `ResultFamily[E]`.

    Args:
        f: The callback, consumed.
        source: The source, consumed.

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
    return M.combine(left^, right^)


# Native functions and closures for every instance. The callback is borrowed
# through a _NativeUnaryRef, never copied. Generic code that forwards a raising
# native callback names its error with X=, which must equal the callback's error.
struct _InferError(Movable where False):
    pass


comptime _EntryError[Expected: AnyType, Actual: Movable & Deinitable]: Movable & Deinitable = (
    downcast[Expected, Movable & Deinitable] if conforms_to(Expected, Movable & Deinitable) else Actual
)


# The where clause relates the callback's input to the carrier's element at the
# call, where origins are compared; the instance's own check runs after they are
# erased. Signatures name the instance's error through a probe that carries only the
# callback's types: a member alias of a struct holding the native function is not
# reduced in a raises clause on Mojo 1.1. The body checks that the probe and the
# stored callback give the instance the same error.
struct _ErrorProbe[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable](UnaryContract):
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E


# Keep the native signature at the call site while borrowing its closure. On
# Mojo 1.2 an out-of-line entry can give the reference adapter invalid capture
# storage at O0 after generic forwarding. The family still owns execution.
@always_inline
def map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
        I: Functor, F: _Unary[A, R]](ref[o] f: F, var value: V
) raises I.MapError[V, _ErrorProbe[A, R, Never]] -> I.Mapped[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A and _MapCompatible[I, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Apply a native function or closure to each element of `value`."""
    return _map_native[V, A, R, Never, I, F, False, o](f, value^)


@always_inline
def map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
        I: Functor, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](ref[o] f: F, var value: V
) raises _EntryError[X, I.MapError[V, _ErrorProbe[A, R, E]]] -> I.Mapped[V, _NativeUnaryRef[A, R, E, F, True, o]] where (
        I.Element[V] == A and _MapCompatible[I, V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E)):
    """Apply a raising native callback; its error type is kept."""
    return _map_native[V, A, R, E, I, F, True, o,
        _EntryError[X, I.MapError[V, _ErrorProbe[A, R, E]]]](f, value^)


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


@always_inline
def flat_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
             I: Monad, F: _Unary[A, R]](ref[o] f: F, var value: V
) raises I.BindError[V, _ErrorProbe[A, R, Never]] -> I.Bound[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A and _BindCompatible[I, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Let a native function or closure choose the next carrier."""
    comptime D = _NativeUnaryRef[A, R, Never, F, False, o]
    comptime Raised = I.BindError[V, _ErrorProbe[A, R, Never]]
    comptime assert I.BindError[V, D] == Raised
    comptime assert _ErrorCompatible[Raised, I.BindError[V, D]]
    return _flat_map_as[Raised, I](D(Pointer(to=f)), value^)


@always_inline
def flat_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
             I: Monad, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](ref[o] f: F, var value: V
) raises _EntryError[X, I.BindError[V, _ErrorProbe[A, R, E]]] -> I.Bound[V, _NativeUnaryRef[A, R, E, F, True, o]] where (
        I.Element[V] == A and _BindCompatible[I, V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E)):
    """Raising form of the native flat_map; its error type is kept."""
    comptime D = _NativeUnaryRef[A, R, E, F, True, o]
    comptime Raised = _EntryError[X, I.BindError[V, _ErrorProbe[A, R, E]]]
    comptime assert I.BindError[V, D] == I.BindError[V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, I.BindError[V, D]]
    return _flat_map_as[Raised, I](D(Pointer(to=f)), value^)


def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
             S: Traversable, G: Applicative, F: _Unary[A, R]](ref[o] f: F, var source: V
) raises S.TraverseError[G, V, _ErrorProbe[A, R, Never]] -> S.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]] where S.Element[V] == A and S.TargetCompatible[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Traverse with a native function or closure."""
    comptime D = _NativeUnaryRef[A, R, Never, F, False, o]
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[A, R, Never]]
    comptime assert S.TraverseError[G, V, D] == Raised
    return _traverse_as[S, G, V, D, Raised](D(Pointer(to=f)), source^)


def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
             S: Traversable, G: Applicative, F: _RaisingUnary[A, R, E]](ref[o] f: F, var source: V
) raises S.TraverseError[G, V, _ErrorProbe[A, R, E]] -> S.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]] where S.Element[V] == A and S.TargetCompatible[G, V, _NativeUnaryRef[A, R, E, F, True, o]]:
    """Traverse with a raising native callback; its error type is kept."""
    comptime D = _NativeUnaryRef[A, R, E, F, True, o]
    comptime Raised = S.TraverseError[G, V, _ErrorProbe[A, R, E]]
    comptime assert S.TraverseError[G, V, D] == Raised
    return _traverse_as[S, G, V, D, Raised](D(Pointer(to=f)), source^)
