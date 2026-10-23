"""Stored failures and recovery derived from the selected family's capability."""
from .protocols import Applicative, ApplicativeError, Monad
from std.builtin.rebind import downcast, rebind_var
from fp._internal.errors import _ErrorCompatible, _CommonError, _propagate_error, _absurd
from ._adapt import _flat_map_as, _or_else_as, _map2_lazy_as
from fp.callables.protocols import UnaryContract, OnceUnary, MutableUnary, BorrowCallContract, Binary, OnceThunk
from fp.callables._conditional import _guard_owned
from fp.callables._receiver import _RepeatableBorrow, _MutableBorrowRef, _MutableUnaryRef, _unary_once_as
from fp.callables._transforms import _ObserveOnce
from ._sequencing import _EffectRetain
from ._traversal import _EffectVoid
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary


# A conditional type alias can expose only the common traits of its branches
# on Mojo 1.1, even when conforms_to sees the selected error-capable family.
# Recover the native witness here; callers still use the original family alias.
comptime _ErrorFamily[I: Applicative] = downcast[I, ApplicativeError]


def fail[I: Applicative, A: Movable & Deinitable](var error: _ErrorFamily[I].Failure
) raises _ErrorFamily[I].FailError[A] -> _ErrorFamily[I].Failed[A] where conforms_to(I, ApplicativeError):
    """Construct a stored failure in the explicitly selected family.

    This does not raise the supplied error or catch native exceptions.
    Deferred families keep their normal evaluation and ownership rules.

    Parameters:
        I: A family implementing ApplicativeError, selecting its stored-error layer.
        A: The success payload type, needed because no success value is supplied.

    Args:
        error: The stored error, consumed with its exact type and origins.

    Returns:
        I.Failed[A], the family's failed carrier.

    Raises:
        I.FailError[A], the family's exact native construction error.
    """
    return _ErrorFamily[I].fail[A](error^)


@fieldwise_init
struct _Recovered[I: Applicative, H: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[H], Copyable where conforms_to(H, Copyable)
):
    """Lift a value-returning recovery handler through the family's pure."""
    var handler: Self.H
    comptime Arg = Self.H.Arg
    comptime Out = Self.I.Pure[Self.H.Out]
    comptime Error = Self.H.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self.I.pure(call_once(self.handler^, arg^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.H], "recover: branching requires a repeatable handler"
        return Self.I.pure(call_repeated(self.handler, arg^))


struct _Continue[M: Monad, recover: Bool]:
    """Select the base operation; deferred transformers own only their run boundary."""
    comptime Errors = downcast[Self.M, ApplicativeError]
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Errors.Handled[V, H] if Self.recover else Self.M.Bound[V, H]
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Errors.HandleError[V, H] if Self.recover else Self.M.BindError[V, H]

    @staticmethod
    def apply[E: Movable & Deinitable, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises E -> Self.Out[V, H] where _ErrorCompatible[E, Self.Error[V, H]]:
        comptime if Self.recover:
            comptime assert _ErrorCompatible[E, Self.Errors.HandleError[V, H]]
            comptime assert Self.Errors._Handles[V, H], "or_else: base carrier or handler mismatch"
            return rebind_var[Self.Out[V, H]](_or_else_as[E, Self.Errors](handler^, source^))
        else:
            comptime assert _ErrorCompatible[E, Self.M.BindError[V, H]]
            return rebind_var[Self.Out[V, H]](_flat_map_as[E, Self.M](handler^, source^))


@fieldwise_init
struct _ConditionalRecovery[I: ApplicativeError, A: Movable & Deinitable,
                            C: BorrowCallContract & Movable & Deinitable,
                            H: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where _RepeatableBorrow[C] and RepeatableUnary[H],
    Copyable where conforms_to(C, Copyable) and conforms_to(H, Copyable)
):
    """Handle matching errors; preserve others through the selected family."""
    var predicate: Self.C
    var handler: Self.H
    comptime Arg = Self.I.Failure
    comptime Out = Self.I._Joined[Self.I.Failed[Self.A], Self.H.Out]
    comptime Error = _CommonError[Self.C.Failure, _CommonError[Self.H.Error, Self.I.FailError[Self.A]]]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.H.Arg == Self.Arg
        comptime assert _ErrorCompatible[Self.Error, Self.H.Error] and _ErrorCompatible[Self.Error, Self.I.FailError[Self.A]], "conditional recovery: incompatible native errors"
        def keep(var error: Self.Arg) raises Self.Error capturing -> Self.Out:
            try:
                return Self.I._join_left[Self.I.Failed[Self.A], Self.H.Out](Self.I.fail[Self.A](error^))
            except raised:
                _propagate_error[Self.Error](raised^)
        def apply(var error: Self.Arg, var handler: Self.H) raises Self.Error capturing -> Self.Out:
            return Self.I._join_right[Self.I.Failed[Self.A], Self.H.Out](_unary_once_as[Self.Error](handler^, rebind_var[Self.H.Arg](error^)))
        return _guard_owned[Self.Arg, Self.C, Self.H, Self.Out, Self.Error, True, keep, apply](arg^, self.predicate^, self.handler^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C] and RepeatableUnary[Self.H], "conditional recovery: branching requires repeatable callbacks"
        var predicate = _MutableBorrowRef(Pointer(to=self.predicate))
        var handler = _MutableUnaryRef(Pointer(to=self.handler))
        return _ConditionalRecovery[Self.I, Self.A, type_of(predicate), type_of(handler)](predicate^, handler^).call_once(arg^)


@fieldwise_init
struct _FailedThunk[I: ApplicativeError](OnceThunk, Copyable where conforms_to(I.Failure, Copyable)):
    """Defer reintroducing an error until combination demands its right operand."""
    var error: Self.I.Failure
    comptime Out = Self.I.Failed[Never]
    comptime Error = Self.I.FailError[Never]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return Self.I.fail[Never](self.error^)


@fieldwise_init
struct _UninhabitedRight[A: Movable & Deinitable](Binary, Copyable, Defaultable):
    # A failed right operand has no success payload. Native Never avoids
    # copying a nonexistent A when branching families cache that operand.
    comptime First = NoneType
    comptime Second = Never
    comptime Out = Self.A
    def call(self, var first: NoneType, var second: Never) -> Self.A:
        return _absurd[Self.A](second)


@fieldwise_init
struct _ObserveFailure[I: ApplicativeError, A: Movable & Deinitable, V: Movable & Deinitable](Binary, Defaultable):
    """Combine an observer with the retained failure using the family's policy."""
    comptime First = Self.I.Failure
    comptime Second = Self.V
    comptime Discard = _EffectVoid[Self.I, Self.V]
    comptime Voided = Self.Discard.Out
    comptime Join = _UninhabitedRight[Self.A]
    comptime Next = _FailedThunk[Self.I]
    comptime Out = Self.I.Combined[Self.Voided, Self.Join, Self.Next]
    comptime Error = _CommonError[Self.Discard.Error, Self.I.CombineError[Self.Voided, Self.Join, Self.Next]]
    def call(self, var original: Self.First, var observed: Self.V) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.Discard.Error]
        comptime assert _ErrorCompatible[Self.Error, Self.I.CombineError[Self.Voided, Self.Join, Self.Next]], "error observation: incompatible native errors"
        var discarded = _unary_once_as[Self.Error](Self.Discard(), observed^)
        return _map2_lazy_as[Self.Error, Self.I](Self.Join(), discarded^, Self.Next(original^))


struct _ErrorObservation[I: ApplicativeError, A: Movable & Deinitable, V: Movable & Deinitable,
                         X: Movable & Deinitable, effect: Bool]:
    # Flat metadata lets native generic forwarders retain exact raised errors.
    comptime Out = _ObserveFailure[Self.I, Self.A, Self.V].Out if Self.effect else Self.I.Failed[Self.A]
    comptime Error = _CommonError[Self.X, _ObserveFailure[Self.I, Self.A, Self.V].Error if Self.effect else Self.I.FailError[Self.A]]


@fieldwise_init
struct _ObserveError[I: ApplicativeError, A: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, effect: Bool](
    OnceUnary, MutableUnary where _RepeatableBorrow[C], Copyable where conforms_to(C, Copyable)
):
    """Observe the selected error; families retain all branching and error policy."""
    var function: Self.C
    comptime Arg = Self.I.Failure
    comptime Out = _ErrorObservation[Self.I, Self.A, Self.C.Result, Self.C.Failure, Self.effect].Out
    comptime Error = _ErrorObservation[Self.I, Self.A, Self.C.Result, Self.C.Failure, Self.effect].Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime if Self.effect:
            comptime assert Self.I._ErrorCarrier[Self.C.Result], "error observation: observer must return the selected family"
            comptime Keep = _EffectRetain[Self.Arg, Self.I, Self.C, False, False, _ObserveFailure[Self.I, Self.A, Self.C.Result]]
            comptime assert _ErrorCompatible[Self.Error, Keep.Error]
            comptime assert Self.Out == Keep.Out
            return rebind_var[Self.Out](_unary_once_as[Self.Error](Keep(self.function^), arg^))
        else:
            comptime assert _ErrorCompatible[Self.Error, Self.C.Failure] and _ErrorCompatible[Self.Error, Self.I.FailError[Self.A]]
            var original = _unary_once_as[Self.Error](_ObserveOnce[Self.Arg, Self.C, False](self.function^), arg^)
            try:
                comptime assert Self.Out == Self.I.Failed[Self.A]
                return rebind_var[Self.Out](Self.I.fail[Self.A](original^))
            except raised:
                _propagate_error[Self.Error](raised^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C], "error observation: branching requires a repeatable callback"
        var callback = _MutableBorrowRef(Pointer(to=self.function))
        return _ObserveError[Self.I, Self.A, type_of(callback), Self.effect](callback^).call_once(arg^)
