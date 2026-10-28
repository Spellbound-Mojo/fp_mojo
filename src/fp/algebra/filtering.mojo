"""Container filtering and selection rules over the existing accumulation loop."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables._views import _BorrowViewable
from fp.callables._predicates import _Negated, _FilterPredicate
from fp.callables.protocols import BorrowCallContract, BorrowCallable, Unary, UnaryContract, MutableUnary
from fp.iteration._callbacks import _predicate_callable, _predicate_repeated
from fp.callables.native import _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from .protocols import Filterable, FunctorFilter, _Accumulate
from ._primitive_contracts import FilterContract
from fp.callables.invoke import RepeatableBorrow
from fp.callables.native import _Unary, _RaisingUnary, _NativeUnaryRef
from fp.callables._identity import Identity
from fp.callables._transforms import _selected


def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, //, I: Filterable](var predicate: P, var value: V
) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
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
        predicate: The predicate, consumed; it only borrows each payload.
        value: The carrier, consumed.

    Returns:
        The family's carrier of accepted values, with their origins unchanged.

    Raises:
        The family's exact filtering error.
    """
    return _filter_with[V, P, I, False](predicate^, value^)


def filter[V: Movable & Deinitable, P: _BorrowViewable, o: ImmOrigin, //, I: Filterable](ref[o] predicate: P, var value: V
) raises FilterContract[I, V, P._BorrowView[o]].Error -> FilterContract[I, V, P._BorrowView[o]].Out where FilterContract[I, V, P._BorrowView[o]].Compatible:
    """Filter through an explicit family while retaining a shared predicate."""
    return filter[I](predicate._borrow_view(), value^)


def filter[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
           I: Filterable, F: _Borrowing[P, R]](ref[o] predicate: F, var value: V
) raises I.FilterError[V, _NativeBorrowRef[P, Bool, Never, F, False, o]] -> I.Filtered[V, _NativeBorrowRef[P, Bool, Never, F, False, o]] where I.Element[V] == P and R == Bool:
    """Filter with a borrowed native predicate; its captures stay in place."""
    return _filter_native[V, P, Never, I, F, False, o](predicate, value^)


def filter[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
           I: Filterable, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](ref[o] predicate: F, var value: V
) raises I.FilterError[V, _NativeBorrowRef[P, Bool, E, F, True, o]] -> I.Filtered[V, _NativeBorrowRef[P, Bool, E, F, True, o]] where I.Element[V] == P and R == Bool:
    """Filter with a raising native predicate; generic forwarding names E explicitly."""
    return _filter_native[V, P, E, I, F, True, o](predicate, value^)


def filter_not[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, //, I: Filterable](var predicate: P, var value: V
) raises FilterContract[I, V, P, True].Error -> FilterContract[I, V, P, True].Out where FilterContract[I, V, P, True].Compatible:
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
        predicate: The predicate, consumed; it only borrows each payload.
        value: The carrier, consumed.

    Returns:
        The family's carrier of rejected values, with their origins unchanged.

    Raises:
        The family's exact error for filtering with the adapted predicate.
    """
    return _filter_with[V, P, I, True](predicate^, value^)


def filter_not[V: Movable & Deinitable, P: _BorrowViewable, o: ImmOrigin, //, I: Filterable](ref[o] predicate: P, var value: V
) raises FilterContract[I, V, P._BorrowView[o], True].Error -> FilterContract[I, V, P._BorrowView[o], True].Out where FilterContract[I, V, P._BorrowView[o], True].Compatible:
    """Filter through an explicit family while retaining a shared predicate."""
    return filter_not[I](predicate._borrow_view(), value^)


def filter_not[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               I: Filterable, F: _Borrowing[P, R]](ref[o] predicate: F, var value: V
) raises I.FilterError[V, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]] -> I.Filtered[V, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]] where I.Element[V] == P and R == Bool:
    """Retain rejected payloads with a borrowed native predicate."""
    return _filter_native[V, P, Never, I, F, False, o, True](predicate, value^)


def filter_not[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               I: Filterable, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](ref[o] predicate: F, var value: V
) raises I.FilterError[V, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]] -> I.Filtered[V, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]] where I.Element[V] == P and R == Bool:
    """Retain rejected payloads with a raising native predicate; forward E explicitly."""
    return _filter_native[V, P, E, I, F, True, o, True](predicate, value^)


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
                   inverted: Bool = False](
    ref[o] predicate: F, var value: V
) raises I.FilterError[V, _FilterPredicate[_NativeBorrowRef[T, Bool, E, F, raising, o], inverted]] -> I.Filtered[V, _FilterPredicate[_NativeBorrowRef[T, Bool, E, F, raising, o], inverted]]:
    # Explicit parameters keep native signature evidence through Piped as well
    # as the free operations. Both polarities borrow the callback in place;
    # all native invocation belongs to callables.native.
    comptime C = _NativeBorrowRef[T, Bool, E, F, raising, o]
    return _filter_with[V, C, I, inverted](C(Pointer(to=predicate)), value^)


@fieldwise_init
struct _Select[T: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](
    UnaryContract, Movable, Deinitable,
    Unary where conforms_to(P, BorrowCallable), MutableUnary where RepeatableBorrow[P]
):
    var predicate: Self.P
    comptime Arg = Self.T
    comptime Out = Optional[Self.T]
    comptime Error = Self.P.Failure
    def call(self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.P, BorrowCallable)
        comptime Shared = downcast[Self.P, BorrowCallable]
        var accepted = _predicate_callable[Self.T, Shared, Self.Error](arg, rebind[Shared](self.predicate))
        return _selected(arg^, accepted)

    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert RepeatableBorrow[Self.P] and Self.P.Payload == Self.T and Self.P.Result == Bool
        var accepted = _predicate_repeated[Self.T, Self.P, origin_of(self.predicate), Self.Error](arg, Pointer(to=self.predicate))
        return _selected(arg^, accepted)


struct _Keep[K: _Accumulate](_Accumulate):
    """Discard absent payloads; reuse the native accumulator's insertion rule."""
    comptime Acc = Self.K.Acc
    comptime Item = Optional[Self.K.Item]
    comptime Error = Self.K.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Self.K.start()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Self.K.live(acc)
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if item:
            return Self.K.combine(acc^, item.unsafe_take())
        return acc^


def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: FunctorFilter](
    var function: F, var value: V
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
        function: The callback, consumed; calls follow the operation's evaluation order.
        value: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The carrier of present transformed Optional payloads, in source order.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return I.filter_map(function^, value^)


def filter_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
               I: FunctorFilter, F: _Unary[A, R]](ref[o] function: F, var value: V
) raises I.MapFilterError[V, _NativeUnaryRef[A, R, Never, F, False, o]] -> I.MapFiltered[V, _NativeUnaryRef[A, R, Never, F, False, o]] where I.Element[V] == A:
    """Transform and select with a borrowed non-raising native callback."""
    return I.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), value^)


def filter_map[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
               I: FunctorFilter, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var value: V
) raises I.MapFilterError[V, _NativeUnaryRef[A, R, E, F, True, o]] -> I.MapFiltered[V, _NativeUnaryRef[A, R, E, F, True, o]] where I.Element[V] == A:
    """Transform and select with a borrowed native callback, retaining its exact error."""
    return I.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), value^)


def compact[V: Movable & Deinitable, //, I: FunctorFilter](var value: V
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
