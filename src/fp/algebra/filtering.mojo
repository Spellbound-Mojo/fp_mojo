"""Container filtering and selection rules over the existing accumulation loop."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables._views import _BorrowViewable
from fp.callables._predicates import _Negated, _FilterPredicate
from fp.callables.protocols import BorrowCallContract, BorrowCallable, Unary, UnaryContract, MutableUnary, _ErrorProbe, _BorrowErrorProbe
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.callables.native import _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from .protocols import Filterable, FunctorFilter, _Accumulate, _filter_map_as
from .collections import _SourceFamily
from ._primitive_contracts import FilterContract
from fp.callables.invoke import RepeatableBorrow
from fp.callables.native import _Unary, _RaisingUnary, _NativeUnaryRef
from fp.callables._identity import Identity


def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, //, I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, var predicate: P) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
    """Filter a carrier through an explicit family, preserving its context.

    Native functions and closures are accepted directly and borrowed. A library
    repeatable borrowing callback is consumed; shared partial predicates may instead be borrowed
    by name. Built-in families run now, call once per payload
    in native order, move accepted values unchanged and destroy rejected values.
    Empty carriers skip calls. Failure destroys remaining input and partial output.
    Deferred families retain their own evaluation and error semantics and may
    retain the native callback borrow. Keep it alive and unmoved until completion.
    Generic forwarding of a raising native callback names its error with E=.

    Parameters:
        V: The carrier type.
        P: The borrowing Bool predicate's type.
        I: The Filterable family, such as ListFamily or OptionalFamily.

    Args:
        value: The carrier, consumed.
        predicate: The predicate, consumed; it only borrows each payload.

    Returns:
        The family's carrier of accepted values, with their origins unchanged.

    Raises:
        The family's exact filtering error.
    """
    return _filter_with[V, P, I, False](predicate^, value^)


def filter[V: Movable & Deinitable, P: _BorrowViewable, o: ImmOrigin, //, I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: P) raises FilterContract[I, V, P._BorrowView[o]].Error -> FilterContract[I, V, P._BorrowView[o]].Out where FilterContract[I, V, P._BorrowView[o]].Compatible:
    """Filter through an explicit family while retaining a shared predicate."""
    return filter[I](value^, predicate._borrow_view())


def filter[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, F: _Borrowing[P, R], //,
           I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: F) raises I.FilterError[V, _NativeBorrowRef[P, Bool, Never, F, False, o]] -> I.Filtered[V, _NativeBorrowRef[P, Bool, Never, F, False, o]] where I.Element[V] == P and R == Bool:
    """Filter with a borrowed native predicate; its captures stay in place."""
    return _filter_native[V, P, Never, I, F, False, o](predicate, value^)


def filter[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], //,
           I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: F) raises I.FilterError[V, _BorrowErrorProbe[P, Bool, E]] -> I.Filtered[V, _NativeBorrowRef[P, Bool, E, F, True, o]] where I.Element[V] == P and R == Bool:
    """Filter with a raising native predicate; generic forwarding names E explicitly."""
    comptime assert I.FilterError[V, _NativeBorrowRef[P, Bool, E, F, True, o]] == I.FilterError[V, _BorrowErrorProbe[P, Bool, E]]
    return _filter_native[V, P, E, I, F, True, o, False, I.FilterError[V, _BorrowErrorProbe[P, Bool, E]]](predicate, value^)


def filter_not[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, //, I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, var predicate: P) raises FilterContract[I, V, P, True].Error -> FilterContract[I, V, P, True].Out where FilterContract[I, V, P, True].Compatible:
    """Retain payloads the predicate rejects, through an explicit family.

    This derives from the family's filter operation. Each predicate result is
    inverted; input ownership, evaluation, result origins and errors otherwise
    follow filter. Native callbacks are borrowed, library predicates consumed.
    Deferred families may retain that borrow: keep the callback alive and unmoved
    until completion. Generic native forwarding names the family and, for a
    raising callback, its error with E=.

    Parameters:
        V: The carrier type.
        P: The borrowing Bool predicate's type.
        I: The Filterable family, including custom or deferred carriers.

    Args:
        value: The carrier, consumed.
        predicate: The predicate, consumed; it only borrows each payload.

    Returns:
        The family's carrier of rejected values, with their origins unchanged.

    Raises:
        The family's exact error for filtering with the adapted predicate.
    """
    return _filter_with[V, P, I, True](predicate^, value^)


def filter_not[V: Movable & Deinitable, P: _BorrowViewable, o: ImmOrigin, //, I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: P) raises FilterContract[I, V, P._BorrowView[o], True].Error -> FilterContract[I, V, P._BorrowView[o], True].Out where FilterContract[I, V, P._BorrowView[o], True].Compatible:
    """Filter through an explicit family while retaining a shared predicate."""
    return filter_not[I](value^, predicate._borrow_view())


def filter_not[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, F: _Borrowing[P, R], //,
               I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: F) raises I.FilterError[V, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]] -> I.Filtered[V, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]] where I.Element[V] == P and R == Bool:
    """Retain rejected payloads with a borrowed native predicate."""
    return _filter_native[V, P, Never, I, F, False, o, True](predicate, value^)


def filter_not[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], //,
               I: Filterable = downcast[_SourceFamily[V], Filterable]](var value: V, ref[o] predicate: F) raises I.FilterError[V, _Negated[_BorrowErrorProbe[P, Bool, E]]] -> I.Filtered[V, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]] where I.Element[V] == P and R == Bool:
    """Retain rejected payloads with a raising native predicate; forward E explicitly."""
    comptime assert I.FilterError[V, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]] == I.FilterError[V, _Negated[_BorrowErrorProbe[P, Bool, E]]]
    return _filter_native[V, P, E, I, F, True, o, True, I.FilterError[V, _Negated[_BorrowErrorProbe[P, Bool, E]]]](predicate, value^)


def _filter_with[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, I: Filterable, inverted: Bool](
    var predicate: P, var value: V
) raises I.FilterError[V, _FilterPredicate[P, inverted]] -> I.Filtered[V, _FilterPredicate[P, inverted]]:
    # Derive inversion once; every family retains its own construction, error
    # and evaluation behavior. Native callbacks arrive through the same bridge.
    comptime C = _FilterPredicate[P, inverted]
    var selected: C
    comptime if inverted:
        comptime assert C == _Negated[P]
        selected = rebind_var[C](_Negated[P](predicate^))
    else:
        comptime assert C == P
        selected = rebind_var[C](predicate^)
    # Keep the exact associated error type at a single invocation. Mojo 1.1
    # does not refine I.FilterError through a branch on the predicate's type.
    return I.filter(selected^, value^)


def _filter_native[V: Movable & Deinitable, T: AnyType, E: Movable & Deinitable,
                   I: Filterable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin,
                   inverted: Bool = False,
                   Raised: Movable & Deinitable = I.FilterError[V, _FilterPredicate[_NativeBorrowRef[T, Bool, E, F, raising, o], inverted]]](
    ref[o] predicate: F, var value: V
) raises Raised -> I.Filtered[V, _FilterPredicate[_NativeBorrowRef[T, Bool, E, F, raising, o], inverted]]:
    # Explicit parameters keep native signature evidence through Piped as well
    # as the free operations. Both polarities borrow the callback in place;
    # all native invocation belongs to callables.native. A caller whose family
    # is defaulted names its error through _BorrowErrorProbe as Raised.
    comptime C = _NativeBorrowRef[T, Bool, E, F, raising, o]
    try:
        return _filter_with[V, C, I, inverted](C(Pointer(to=predicate)), value^)
    except error:
        comptime assert _ErrorCompatible[Raised, type_of(error)]
        _propagate_error[Raised](error^)


def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: FunctorFilter = downcast[_SourceFamily[V], FunctorFilter]](
    var value: V, var function: F
) raises I.MapFilterError[V, F] -> I.MapFiltered[V, F]:
    """Transform through a FunctorFilter family and retain present Optional results.

    Built-in families consume each input once, move present results into their
    native output container and discard absent results. Native callbacks are
    borrowed; library callbacks are consumed. Deferred families retain their
    evaluation, origins and exact error semantics.

    Parameters:
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.
        I: The explicit capability family, including its result and error semantics.

    Args:
        value: The source, consumed with its native origins; iterator sources are not restarted.
        function: The callback, consumed; calls follow the operation's evaluation order.

    Returns:
        The carrier of present transformed Optional payloads, in source order.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return I.filter_map(function^, value^)


def filter_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Unary[A, R], //,
               I: FunctorFilter = downcast[_SourceFamily[V], FunctorFilter]](var value: V, ref[o] function: F) raises I.MapFilterError[V, _NativeUnaryRef[A, R, Never, F, False, o]] -> I.MapFiltered[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A:
    """Transform and select with a borrowed non-raising native callback."""
    return I.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), value^)


def filter_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], //,
               I: FunctorFilter = downcast[_SourceFamily[V], FunctorFilter]](var value: V, ref[o] function: F) raises I.MapFilterError[V, _ErrorProbe[A, R, E]] -> I.MapFiltered[V, _NativeUnaryRef[A, R, E, F, True, o]] where I.Element[V] == A:
    """Transform and select with a borrowed native callback, retaining its exact error."""
    comptime D = _NativeUnaryRef[A, R, E, F, True, o]
    comptime Raised = I.MapFilterError[V, _ErrorProbe[A, R, E]]
    comptime assert I.MapFilterError[V, D] == Raised
    return _filter_map_as[Raised, I](D(Pointer(to=function)), value^)


def compact[V: Movable & Deinitable, //, I: FunctorFilter = downcast[_SourceFamily[V], FunctorFilter]](var value: V
) raises I.MapFilterError[V, Identity[I.Element[V]]] -> I.MapFiltered[V, Identity[I.Element[V]]]:
    """Unwrap present Optional payloads through the family's filter_map operation.

    Parameters:
        V: The consumed source or carrier type.
        I: The explicit capability family, including its result and error semantics.

    Args:
        value: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The carrier of unwrapped present Optional payloads, in source order.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return I.filter_map(Identity[I.Element[V]](), value^)
