"""Derived iterator combinators; callbacks and traversal keep canonical owners."""
from fp.algebra._admission import _CarrierCompatible
from fp.functions.composition import Identity as _Same
from fp._internal.errors import _CommonError, _ErrorCompatible

from fp.data._result import _ResultType
from fp.algebra.operations import _EntryError, _InferError
from fp.algebra._traversal import _FlattenAfter, _CompactAfter, _traverse_then, _Discard, _TraverseTap, _traverse_void, _traverse_as, _EffectVoid
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import BorrowCallContract

from std.builtin.rebind import downcast
from fp.callables.protocols import BorrowCallable, UnaryContract
from fp.callables.native import _Borrowing, _RaisingBorrowing, _NativeBorrowRef, _Unary, _RaisingUnary, _NativeUnaryRef
from fp.algebra.protocols import Applicative
from fp.callables._transforms import _Fill, _Replace, _TupleWith, _Observe, _ObserveNative
from ._advance import _Source, _source
from .adapters import _Map, _FilterMap
from fp.functions.composition import Identity
from fp.algebra.instances import _ListElement, ListFamily


def fill[U: Copyable & Deinitable, I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[_Source[I].Element, Movable & Deinitable]](
    var value: U, var source: I
) -> _Map[T, U, _Source[I], _Fill[T, U]] where _Source[I].Element == T:
    """Copy value into every payload position. Evaluation is lazy; source and constant arguments are consumed.

    Parameters:
        U: The constant or result payload type; repeated constants must be Copyable.
        I: The native source type: an iterator at its current position or an owned iterable.
        T: The element type, including its native origins.

    Args:
        value: The constant, consumed and copied once per emitted payload.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape with a copy of value at each payload position; empty input stays empty.
    """
    return _Map[T, U, _Source[I], _Fill[T, U]](_Fill[T, U](value^), _source(source^), False)


def replace[T: Copyable & Equatable & Deinitable, I: Movable & Deinitable, //](
    var old: T, var new: T, var source: I
) -> _Map[T, T, _Source[I], _Replace[T]] where _Source[I].Element == T:
    """Replace equal payloads, moving unmatched values unchanged. Evaluation is lazy; source and constant arguments are consumed.

    Parameters:
        T: The element type, including its native origins.
        I: The native source type: an iterator at its current position or an owned iterable.

    Args:
        old: The value to compare against each payload, consumed.
        new: The replacement, consumed and copied only for matching payloads.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape with matching elements replaced and unmatched elements moved unchanged.
    """
    return _Map[T, T, _Source[I], _Replace[T]](_Replace[T](old^, new^), _source(source^), False)


def void[I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[_Source[I].Element, Movable & Deinitable]](
    var source: I
) -> _Map[T, NoneType, _Source[I], _Fill[T, NoneType]] where _Source[I].Element == T:
    """Discard payloads while preserving their container shape. Evaluation is lazy; source and constant arguments are consumed.

    Parameters:
        I: The native source type: an iterator at its current position or an owned iterable.
        T: The element type, including its native origins.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape with NoneType payloads; a lazy iterator is not drained.
    """
    return _Map[T, NoneType, _Source[I], _Fill[T, NoneType]](_Fill[T, NoneType](None), _source(source^), False)


def tuple_left[U: Copyable & Deinitable, I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[_Source[I].Element, Movable & Deinitable]](
    var value: U, var source: I
) -> _Map[T, Tuple[U, T], _Source[I], _TupleWith[T, U, True]] where _Source[I].Element == T:
    """Pair each payload with a copy of value on the left. Evaluation is lazy; source and constant arguments are consumed.

    Parameters:
        U: The constant or result payload type; repeated constants must be Copyable.
        I: The native source type: an iterator at its current position or an owned iterable.
        T: The element type, including its native origins.

    Args:
        value: The constant, consumed and copied once per emitted payload.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape containing a copied constant followed by each original element.
    """
    return _Map[T, Tuple[U, T], _Source[I], _TupleWith[T, U, True]](_TupleWith[T, U, True](value^), _source(source^), False)


def tuple_right[U: Copyable & Deinitable, I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[_Source[I].Element, Movable & Deinitable]](
    var value: U, var source: I
) -> _Map[T, Tuple[T, U], _Source[I], _TupleWith[T, U, False]] where _Source[I].Element == T:
    """Pair each payload with a copy of value on the right. Evaluation is lazy; source and constant arguments are consumed.

    Parameters:
        U: The constant or result payload type; repeated constants must be Copyable.
        I: The native source type: an iterator at its current position or an owned iterable.
        T: The element type, including its native origins.

    Args:
        value: The constant, consumed and copied once per emitted payload.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape containing each original element followed by a copied constant.
    """
    return _Map[T, Tuple[T, U], _Source[I], _TupleWith[T, U, False]](_TupleWith[T, U, False](value^), _source(source^), False)


def pair_with[P: AnyType, R: Movable & Deinitable, I: Movable & Deinitable, //, F: _Borrowing[P, R]](
    var function: F, var source: I
) -> _Map[downcast[P, Movable & Deinitable], Tuple[downcast[P, Movable & Deinitable], R], _Source[I], _ObserveNative[P, R, F, True]] where _Source[I].Element == downcast[P, Movable & Deinitable]:
    """Borrow each element and pair it with its projection. Calls run lazily; the callback and source are consumed.

    Parameters:
        P: The borrowed callback payload type, including its native origins.
        R: The native callback result type.
        I: The native source type: an iterator at its current position or an owned iterable.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The source shape containing each original element beside its borrowed projection.
    """
    return _Map[downcast[P, Movable & Deinitable], Tuple[downcast[P, Movable & Deinitable], R], _Source[I], _ObserveNative[P, R, F, True]](_ObserveNative[P, R, F, True](function^), _source(source^), False)


def pair_with[C: BorrowCallable, I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[C.Payload, Movable & Deinitable]](
    var function: C, var source: I
) -> _Map[T, Tuple[T, C.Result], _Source[I], _Observe[T, C, True]] where _Source[I].Element == T and C.Payload == T and C.Failure == Never:
    """Borrow each element and pair it with its projection. Calls run lazily; the callback and source are consumed."""
    return _Map[T, Tuple[T, C.Result], _Source[I], _Observe[T, C, True]](_Observe[T, C, True](function^), _source(source^), False)


def tap_each[P: AnyType, R: Movable & Deinitable, I: Movable & Deinitable, //, F: _Borrowing[P, R]](
    var function: F, var source: I
) -> _Map[downcast[P, Movable & Deinitable], downcast[P, Movable & Deinitable], _Source[I], _ObserveNative[P, R, F, False]] where _Source[I].Element == downcast[P, Movable & Deinitable]:
    """Borrow each element and inspect it without changing it. Calls run lazily; the callback and source are consumed.

    Parameters:
        P: The borrowed callback payload type, including its native origins.
        R: The native callback result type.
        I: The native source type: an iterator at its current position or an owned iterable.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The original elements after inspection; callback results are discarded.
    """
    return _Map[downcast[P, Movable & Deinitable], downcast[P, Movable & Deinitable], _Source[I], _ObserveNative[P, R, F, False]](_ObserveNative[P, R, F, False](function^), _source(source^), False)


def tap_each[C: BorrowCallable, I: Movable & Deinitable, //, T: Movable & Deinitable = downcast[C.Payload, Movable & Deinitable]](
    var function: C, var source: I
) -> _Map[T, T, _Source[I], _Observe[T, C, False]] where _Source[I].Element == T and C.Payload == T and C.Failure == Never:
    """Borrow each element and inspect it without changing it. Calls run lazily; the callback and source are consumed."""
    return _Map[T, T, _Source[I], _Observe[T, C, False]](_Observe[T, C, False](function^), _source(source^), False)


def compact[I: Movable & Deinitable, //, T: Movable & Deinitable = _ListElement[downcast[_Source[I].Element, Movable & Deinitable]]](
    var source: I
) -> _FilterMap[Optional[T], T, _Source[I], Identity[Optional[T]]] where _Source[I].Element == Optional[T]:
    """Lazily unwrap present Optional elements and discard absent ones.

    Parameters:
        I: The native source type: an iterator at its current position or an owned iterable.
        T: The element type, including its native origins.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The carrier of unwrapped present Optional payloads, in source order.
    """
    return _FilterMap[Optional[T], T, _Source[I], Identity[Optional[T]]](Identity[Optional[T]](), _source(source^), False)


def traverse[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, G: Applicative](
    ref[o] function: F, var source: V
) raises G.CollectError[V, F._View[o]] -> G.Collected[V, F._View[o]] where _Source[V].Element == F._View[o].Arg:
    """Traverse with a shared callable view, retaining its native origin."""
    return traverse[G](function._unary_view(), source^)


def traverse[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, G: Applicative](
    var function: F, var source: V
) raises G.CollectError[V, F] -> G.Collected[V, F]:
    """Consume a source into an effect containing a List, stopping according to G.

    Parameters:
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.
        G: The target Applicative family; it determines effect sequencing and failure.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing transformed payloads; Iter and direct calls gather a List.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return G.collect(function^, source^)


def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
             G: Applicative, F: _Unary[A, R]](ref[o] function: F, var source: V
) raises G.CollectError[V, _NativeUnaryRef[A, R, Never, F, False, o]] -> G.Collected[V, _NativeUnaryRef[A, R, Never, F, False, o]] where _Source[V].Element == A:
    """Traverse with a borrowed native callback and the target effect."""
    return G.collect(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)


def traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
             G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var source: V
) raises G.CollectError[V, _NativeUnaryRef[A, R, E, F, True, o]] -> G.Collected[V, _NativeUnaryRef[A, R, E, F, True, o]] where _Source[V].Element == A:
    """Traverse with a raising native callback, retaining the target's exact error."""
    return G.collect(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)


def sequence[V: Movable & Deinitable, //, G: Applicative](var source: V
) raises G.CollectError[V, Identity[downcast[_Source[V].Element, Movable & Deinitable]]] -> G.Collected[V, Identity[downcast[_Source[V].Element, Movable & Deinitable]]]:
    """Consume effects into one effect containing a List, stopping according to G.

    Parameters:
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing unwrapped payloads; Iter and direct calls gather a List.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return G.collect(Identity[downcast[_Source[V].Element, Movable & Deinitable]](), source^)



# --- traversal conveniences (generated) ---
# Generated by scripts/generate_traversal_syntax.py; execution stays in algebra._traversal and families.

def traverse_void[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var function: F, var source: V) raises _EntryError[X, G._LoopError[V, F, _Discard[G.Element[F.Out]]]] -> G._Looped[V, F, _Discard[G.Element[F.Out]]] where _Source[V].Element == F.Arg and _CarrierCompatible[G, F.Out]:
    """Traverse effects without retaining successful outputs.

    Parameters:
        F: The callback type, retaining its receiver, captures and error contract.
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_void[V, F, G, _EntryError[X, G._LoopError[V, F, _Discard[G.Element[F.Out]]]]](function^, source^)

def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, G._LoopError[V, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> G._Looped[V, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]] where _Source[V].Element == A and _CarrierCompatible[G, R]:
    """Traverse effects without retaining successful outputs."""
    return _traverse_void[V, _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[V, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)

def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, G._LoopError[V, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> G._Looped[V, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]] where _Source[V].Element == A and _CarrierCompatible[G, R]:
    """Traverse effects without retaining successful outputs."""
    return _traverse_void[V, _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[V, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)

def traverse_tap[C: BorrowCallContract & Movable & Deinitable, V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var function: C, var source: V) raises _EntryError[X, G.CollectError[V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> G.Collected[V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]] where _Source[V].Element == downcast[C.Payload, Movable & Deinitable] and _CarrierCompatible[G, C.Result]:
    """Traverse effects and retain the original payloads on success.

    Parameters:
        C: The borrowing library callback type.
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_as[ListFamily, G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, G.CollectError[V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), source^)

def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, G.CollectError[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> G.Collected[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]] where _Source[V].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R]:
    """Traverse effects and retain the original payloads on success."""
    return _traverse_as[ListFamily, G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, G.CollectError[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), source^)

def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, G.CollectError[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> G.Collected[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]] where _Source[V].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R]:
    """Traverse effects and retain the original payloads on success."""
    return _traverse_as[ListFamily, G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, G.CollectError[V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), source^)

def sequence_void[V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var source: V) raises _EntryError[X, G._LoopError[V, _Same[downcast[_Source[V].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]]]] -> G._Looped[V, _Same[downcast[_Source[V].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]]] where _Source[V].Element == downcast[_Source[V].Element, Movable & Deinitable] and _CarrierCompatible[G, _Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]:
    """Traverse effects without retaining successful outputs.

    Parameters:
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_void[V, _Same[downcast[_Source[V].Element, Movable & Deinitable]], G, _EntryError[X, G._LoopError[V, _Same[downcast[_Source[V].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]]]]](_Same[downcast[_Source[V].Element, Movable & Deinitable]](), source^)

def flat_traverse[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]] where _Source[V].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]], F.Error] and G.Element[F.Out] == List[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out]:
    """Traverse effects and flatten one source-family layer inside the effect.

    Parameters:
        F: The callback type, retaining its receiver, captures and error contract.
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_then[ListFamily, G, V, F, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]]](function^, source^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]())

def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[V].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
    """Traverse effects and flatten one source-family layer inside the effect."""
    return _traverse_then[ListFamily, G, V, _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[V].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
    """Traverse effects and flatten one source-family layer inside the effect."""
    return _traverse_then[ListFamily, G, V, _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]())

def flat_sequence[V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]]] where _Source[V].Element == downcast[_Source[V].Element, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]]]]], Never] and G.Element[_Same[downcast[_Source[V].Element, Movable & Deinitable]].Out] == List[_ListElement[G.Element[_Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]]] and _CarrierCompatible[G, _Same[downcast[_Source[V].Element, Movable & Deinitable]].Out]:
    """Traverse effects and flatten one source-family layer inside the effect.

    Parameters:
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing the source shape after sequencing effects and flattening one source-family layer.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_then[ListFamily, G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]]]]]](_Same[downcast[_Source[V].Element, Movable & Deinitable]](), source^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _Same[downcast[_Source[V].Element, Movable & Deinitable]]]]]())

def traverse_filter[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]] where _Source[V].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]], F.Error] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out]:
    """Traverse effects and retain present Optional payloads inside the effect.

    Parameters:
        F: The callback type, retaining its receiver, captures and error contract.
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_then[ListFamily, G, V, F, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, F], G.MapError[ListFamily.Traversed[G, V, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]]]]](function^, source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, F]]]())

def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[V].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
    """Traverse effects and retain present Optional payloads inside the effect."""
    return _traverse_then[ListFamily, G, V, _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[V].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
    """Traverse effects and retain present Optional payloads inside the effect."""
    return _traverse_then[ListFamily, G, V, _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _NativeUnaryRef[A, R, E, F, True, o]]]]())

def filter_effect[C: BorrowCallContract & Movable & Deinitable, V: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](var function: C, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]] where _Source[V].Element == downcast[C.Payload, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], C.Failure] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result]:
    """Retain elements accepted by an effectful borrowing Bool predicate.

    Parameters:
        C: The borrowing library callback type.
        V: The consumed source or carrier type.
        G: The target Applicative family; it determines effect sequencing and failure.
        X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

    Args:
        function: The callback, consumed; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _traverse_then[ListFamily, G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True](function^), source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]())

def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]] where _Source[V].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], Never] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R]:
    """Retain elements accepted by an effectful borrowing Bool predicate."""
    return _traverse_then[ListFamily, G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]())

def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](ref[o] function: F, var source: V) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]] where _Source[V].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]], E] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R]:
    """Retain elements accepted by an effectful borrowing Bool predicate."""
    return _traverse_then[ListFamily, G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), source^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, V, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]())
# --- end traversal conveniences ---
