"""Stored failures and recovery derived from the selected family's capability."""

from .protocols import _pure, _CALLBACK_ADMISSION, Functor, Applicative, ApplicativeError, ErrorMapping, Monad
from .error_mapping import MapErrContract, _map_err
from ._primitive_contracts import MapContract, BindContract, CombineContract
from .instances import ResultFamily
from fp.data._result import Result, _ResultType
from std.builtin.rebind import downcast, rebind_var
from fp._internal.errors import _ErrorCompatible, _CommonErrorCompatible, _CommonError, _absurd
from ._adapt import _fail_as, _flat_map_as, _or_else_as, _map2_lazy_as
from fp.callables.protocols import UnaryContract, OnceUnary, MutableUnary, BorrowCallContract, Binary, OnceThunk
from fp.callables._conditional import _guard_owned
from fp.callables._receiver import _RepeatableBorrow, _OnceBorrowAvailable, _MutableBorrowRef, _MutableUnaryRef, _unary_once_as
from fp.callables._transforms import _ObserveOnce
from ._sequencing import _EffectRetain
from ._traversal import _EffectVoid
from fp.callables.invoke import _OnceUnaryAvailable, call_once, call_repeated, RepeatableUnary


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
        return _pure[Self.I](call_once(self.handler^, arg^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.H], "recover: branching requires a repeatable handler"
        return _pure[Self.I](call_repeated(self.handler, arg^))


struct RecoverContract[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]:
    """The admission, output and construction error of value-returning recovery.

    A generic wrapper forwards `Compatible`, returns `Out` and raises `Error`
    when calling `piped(value).recover[I](handler)`. This removes the need to
    name the private value-to-pure handler adapter in a public signature.
    Execution remains with the family's recovery primitive. Deferred families
    may construct without raising and retain the handler's error until run.

    Compatible includes the family's declared admission of the adapted handler.
    Generic wrappers forward that complete predicate; expanded wrappers also
    forward OperationCompatible. Native signature inference remains separate.

    Parameters:
        I: The family selecting the stored-error layer to recover.
        V: The complete source carrier type, including origins.
        H: The library handler consuming the stored error and returning a value.
    """
    comptime InputCompatible = Self.H.Arg == Self.I.Failure
    """The handler consumes the exact selected stored-error type and origins."""
    comptime OutputCompatible = Self.H.Out == Self.I.Element[Self.V]
    """The replacement value retains the source payload type and origins."""
    comptime CarrierCompatible = Self.I._ErrorCarrier[Self.V]
    """The source belongs to the family's selected stored-error layer."""
    comptime ReceiverCompatible = _OnceUnaryAvailable[Self.H]
    """The handler supplies a callable consuming, mutable or shared receiver."""
    comptime OperationCompatible = Self.I._Handles[Self.V, Self.Handler] if Self.InputCompatible and Self.OutputCompatible and Self.CarrierCompatible and Self.ReceiverCompatible else False
    """The family's declared admission of the value-lifting handler."""
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.CarrierCompatible and Self.ReceiverCompatible and Self.OperationCompatible
    """Complete selected entry admission, including the adapted family operation."""
    comptime Family = Self.I
    """The unchanged family for fluent continuation over Out."""
    comptime Handler = _Recovered[Self.I, Self.H]
    """The existing adapter lifting a successful handler value through pure."""
    comptime Out = Self.I.Handled[Self.V, Self.Handler]
    """The family's exact recovered carrier, including deferred representations."""
    comptime Error = Self.I.HandleError[Self.V, Self.Handler]
    """The family's exact native construction error, separate from stored errors."""


struct _Continue[M: Monad, recover: Bool]:
    """Select the base operation; deferred transformers own only their run boundary."""
    comptime Errors = downcast[Self.M, ApplicativeError]
    comptime _Bind[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = BindContract[Self.M, V, H]
    comptime FamilyCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Errors._Handles[V, H] if Self.recover else Self._Bind[V, H].FamilyCompatible
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Errors.Handled[V, H] if Self.recover else Self._Bind[V, H].Out
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Errors.HandleError[V, H] if Self.recover else Self._Bind[V, H].Error

    @staticmethod
    def apply[E: Movable & Deinitable, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises E -> Self.Out[V, H] where _ErrorCompatible[E, Self.Error[V, H]]:
        comptime if Self.recover:
            comptime assert _ErrorCompatible[E, Self.Errors.HandleError[V, H]]
            comptime assert Self.Errors._Handles[V, H], _CALLBACK_ADMISSION
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
            return Self.I._join_left[Self.I.Failed[Self.A], Self.H.Out](
                _fail_as[Self.Error, Self.I, Self.A](error^))
        def apply(var error: Self.Arg, var handler: Self.H) raises Self.Error capturing -> Self.Out:
            return Self.I._join_right[Self.I.Failed[Self.A], Self.H.Out](_unary_once_as[Self.Error](handler^, rebind_var[Self.H.Arg](error^)))
        return _guard_owned[Self.Arg, Self.C, Self.H, Self.Out, Self.Error, True, keep, apply](arg^, self.predicate^, self.handler^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C] and RepeatableUnary[Self.H], "conditional recovery: branching requires repeatable callbacks"
        var predicate = _MutableBorrowRef(Pointer(to=self.predicate))
        var handler = _MutableUnaryRef(Pointer(to=self.handler))
        return _ConditionalRecovery[Self.I, Self.A, type_of(predicate), type_of(handler)](predicate^, handler^).call_once(arg^)


struct OrElseIfContract[I: ApplicativeError, V: Movable & Deinitable,
                       P: BorrowCallContract & Movable & Deinitable,
                       H: UnaryContract & Movable & Deinitable]:
    """Admission, output and construction error of conditional effect recovery.

    The predicate borrows the selected stored error. A match transfers it to
    the handler; a nonmatch reintroduces it through the family's fail. Families
    retain their receiver checks, branch behavior and deferred run errors.

    Parameters:
        I: The family selecting the stored-error layer.
        V: The complete source carrier, including origins.
        P: The borrowing Bool predicate, with its receiver and native error.
        H: The consuming handler producing another carrier of the same family.
    """
    comptime InputCompatible = Self.P.Payload == Self.I.Failure and Self.H.Arg == Self.I.Failure
    """Both callbacks receive the exact selected error type and origins."""
    comptime PredicateCompatible = Self.P.Result == Bool
    """The borrowing predicate returns native Bool."""
    comptime CarrierCompatible = Self.I._ErrorCarrier[Self.V] and Self.I._ErrorCarrier[Self.H.Out]
    """The source and replacement belong to the selected stored-error layer."""
    comptime OutputCompatible = Self.I.Element[Self.H.Out] == Self.I.Element[Self.V]
    """The replacement retains the source's success payload and origins."""
    comptime NativeErrorsCompatible = _CommonErrorCompatible[Self.P.Failure,Self.H.Error] and _CommonErrorCompatible[Self.P.Failure,Self.I.FailError[Self.I.Element[Self.V]]] and _CommonErrorCompatible[Self.H.Error,Self.I.FailError[Self.I.Element[Self.V]]]
    """Callbacks and unmatched-error construction share an exact native error."""
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.P] and _OnceUnaryAvailable[Self.H]
    """Both callbacks supply an invocable receiver; family branching adds its own rules."""
    # Predicate result equality belongs to entry admission, not to projecting
    # the continuation's carrier. Keeping it out of this conditional lets
    # native generic wrappers forward a symbolic R == Bool proof unchanged.
    comptime OperationCompatible = Self.I._Handles[Self.V, Self.Continuation] if Self.InputCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.NativeErrorsCompatible and Self.ReceiverCompatible else False
    """The family's declared admission of the conditional continuation."""
    comptime Compatible = Self.InputCompatible and Self.PredicateCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.NativeErrorsCompatible and Self.ReceiverCompatible and Self.OperationCompatible
    """Complete selected conditional recovery admission."""
    comptime Family = Self.I
    """The unchanged family for fluent continuation."""
    comptime Continuation = _ConditionalRecovery[Self.I, Self.I.Element[Self.V], Self.P, Self.H]
    """The existing conditional recovery continuation."""
    comptime Out = Self.I.Handled[Self.V, Self.Continuation]
    """The family's exact handled carrier, including deferred representations."""
    comptime Error = Self.I.HandleError[Self.V, Self.Continuation]
    """Construction error; callback and failure-constructor errors may remain deferred."""


struct RecoverIfContract[I: ApplicativeError, V: Movable & Deinitable,
                        P: BorrowCallContract & Movable & Deinitable,
                        H: UnaryContract & Movable & Deinitable]:
    """Admission, output and construction error of conditional value recovery.

    A generic wrapper forwards Compatible and projects Family, Out and Error
    without naming the private value-lifting or conditional adapters. Unmatched
    errors use the family's fail; success skips both callbacks.

    Parameters:
        I: The family selecting the stored-error layer.
        V: The complete source carrier, including origins.
        P: The borrowing Bool predicate, with its receiver and native error.
        H: The consuming handler returning the source success payload type.
    """
    comptime Handler = _Recovered[Self.I, Self.H]
    """The existing adapter lifting a matching handler value through pure."""
    comptime Operation = OrElseIfContract[Self.I, Self.V, Self.P, Self.Handler]
    """Effect recovery metadata after the value handler is lifted."""
    comptime InputCompatible = Self.Operation.InputCompatible
    """Both callbacks receive the exact selected error type and origins."""
    comptime PredicateCompatible = Self.Operation.PredicateCompatible
    """The borrowing predicate returns native Bool."""
    comptime CarrierCompatible = Self.I._ErrorCarrier[Self.V]
    """The source belongs to the selected stored-error layer."""
    comptime OutputCompatible = Self.H.Out == Self.I.Element[Self.V]
    """The handler returns the source's success payload type and origins."""
    comptime NativeErrorsCompatible = Self.Operation.NativeErrorsCompatible
    """The callbacks share a native error type, or at least one never raises."""
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.P] and _OnceUnaryAvailable[Self.H]
    """The original callbacks supply invocable receivers before value lifting."""
    comptime OperationCompatible = Self.Operation.Compatible
    """The admitted effect-recovery operation after lifting the value handler."""
    comptime Compatible = Self.InputCompatible and Self.PredicateCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.NativeErrorsCompatible and Self.ReceiverCompatible and Self.OperationCompatible
    """Complete selected value-recovery admission through the shared effect contract."""
    comptime Family = Self.I
    """The unchanged family for fluent continuation."""
    comptime Continuation = Self.Operation.Continuation
    """The existing conditional recovery continuation."""
    comptime Out = Self.Operation.Out
    """The family's exact handled carrier, including deferred representations."""
    comptime Error = Self.Operation.Error
    """Construction error; callback and failure-constructor errors may remain deferred."""


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
    comptime _Map = MapContract[Self.I, Self.V, Self.Discard.Discard]
    comptime _Combine = CombineContract[Self.I, Self.Voided, Self.Join, Self.Next]
    comptime Compatible = Self._Map.FamilyCompatible and Self._Combine.OperationCompatible
    comptime Out = Self._Combine.Out
    comptime Error = _CommonError[Self.Discard.Error, Self._Combine.Error]
    def call(self, var original: Self.First, var observed: Self.V) raises Self.Error -> Self.Out:
        comptime assert Self.Compatible, _CALLBACK_ADMISSION
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
        var function = self.function^
        comptime if Self.effect:
            comptime assert Self.I._ErrorCarrier[Self.C.Result], "error observation: observer must return the selected family"
            comptime Keep = _EffectRetain[Self.Arg, Self.I, Self.C, False, False, _ObserveFailure[Self.I, Self.A, Self.C.Result]]
            comptime assert _ErrorCompatible[Self.Error, Keep.Error]
            comptime assert Self.Out == Keep.Out
            return rebind_var[Self.Out](_unary_once_as[Self.Error](Keep(function^), arg^))
        else:
            comptime assert _ErrorCompatible[Self.Error, Self.C.Failure] and _ErrorCompatible[Self.Error, Self.I.FailError[Self.A]]
            var original = _unary_once_as[Self.Error](_ObserveOnce[Self.Arg, Self.C, False](function^), arg^)
            comptime assert Self.Out == Self.I.Failed[Self.A]
            return rebind_var[Self.Out](_fail_as[Self.Error, Self.I, Self.A](original^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C], "error observation: branching requires a repeatable callback"
        var callback = _MutableBorrowRef(Pointer(to=self.function))
        return _ObserveError[Self.I, Self.A, type_of(callback), Self.effect](callback^).call_once(arg^)


struct _ErrorObserverContract[I: ApplicativeError, V: Movable & Deinitable,
                              C: BorrowCallContract & Movable & Deinitable,
                              effect: Bool]:
    """One metadata owner for the existing borrowed-error continuations."""
    comptime InputCompatible = Self.C.Payload == Self.I.Failure
    comptime CarrierCompatible = Self.I._ErrorCarrier[Self.V]
    comptime OutputCompatible = Self.I._ErrorCarrier[Self.C.Result] if Self.effect else True
    comptime FamilyCompatible = Self.CarrierCompatible and Self.OutputCompatible
    comptime _Finish = _ObserveFailure[Self.I,Self.I.Element[Self.V],Self.C.Result]
    comptime NativeErrorsCompatible = (
        (_CommonErrorCompatible[Self.C.Failure,Self._Finish.Discard.Error] and
         _CommonErrorCompatible[Self.C.Failure,Self.I.CombineError[Self._Finish.Voided,Self._Finish.Join,Self._Finish.Next]] and
         _CommonErrorCompatible[Self._Finish.Discard.Error,Self.I.CombineError[Self._Finish.Voided,Self._Finish.Join,Self._Finish.Next]])
        if Self.effect else _CommonErrorCompatible[Self.C.Failure,Self.I.FailError[Self.I.Element[Self.V]]]
    ) if Self.InputCompatible and Self.FamilyCompatible else False
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.C]
    comptime OperationCompatible = (Self.I._Handles[Self.V, Self.Handler] and (Self._Finish.Compatible if Self.effect else True)) if Self.InputCompatible and Self.FamilyCompatible and Self.NativeErrorsCompatible and Self.ReceiverCompatible else False
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible and Self.NativeErrorsCompatible and Self.ReceiverCompatible and Self.OperationCompatible
    comptime Family = Self.I
    comptime Handler = _ObserveError[Self.I, Self.I.Element[Self.V], Self.C, Self.effect]
    comptime Out = Self.I.Handled[Self.V, Self.Handler]
    comptime Error = Self.I.HandleError[Self.V, Self.Handler]


trait _TapErrPolicy:
    comptime CarrierCompatible[V: Movable & Deinitable]: Bool
    comptime NativeErrorsCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]: Bool
    comptime OperationCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]: Bool
    comptime Family[V: Movable & Deinitable]: Functor
    comptime Handler[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]: UnaryContract & Movable & Deinitable
    comptime Out[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    comptime Error[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def apply[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var observer: C, var source: V) raises Self.Error[V,C] -> Self.Out[V,C]: ...


struct _RecoveryTap[I: ApplicativeError](_TapErrPolicy):
    comptime Contract[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = _ErrorObserverContract[Self.I,V,C,False]
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.I._ErrorCarrier[V]
    comptime NativeErrorsCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].NativeErrorsCompatible
    comptime OperationCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].OperationCompatible
    comptime Family[V: Movable & Deinitable] = Self.I
    comptime Handler[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Handler
    comptime Out[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Out
    comptime Error[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Error
    @staticmethod
    def apply[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var observer: C, var source: V) raises Self.Error[V,C] -> Self.Out[V,C]:
        comptime assert Self.Contract[V,C].Compatible
        return _observe_error[Self.I,V,C,False](observer^,source^)


struct _MappingTap[I: ErrorMapping](_TapErrPolicy):
    comptime Handler[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = _ObserveOnce[Self.I.Failure,C,False]
    comptime Contract[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = MapErrContract[Self.I,V,Self.Handler[V,C],Self.I]
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.I.ErrorCarrierCompatible[V]
    comptime NativeErrorsCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = True
    comptime OperationCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Compatible
    comptime Family[V: Movable & Deinitable] = Self.I
    comptime Out[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Out
    comptime Error[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = Self.Contract[V,C].Error
    @staticmethod
    def apply[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var observer: C, var source: V) raises Self.Error[V,C] -> Self.Out[V,C]:
        comptime assert Self.Contract[V,C].Compatible
        return _map_err[Self.I,V,Self.Handler[V,C],Self.I](Self.Handler[V,C](observer^),source^)


struct _IntrinsicTap(_TapErrPolicy):
    comptime Family[V: Movable & Deinitable] = ResultFamily[downcast[V,_ResultType].Error]
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.Family[V]._ErrorCarrier[V] if conforms_to(V,_ResultType) else False
    comptime NativeErrorsCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = True
    comptime OperationCompatible[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = True
    comptime Handler[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = _ObserveOnce[Self.Family[V].Failure,C,False]
    comptime Out[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = V
    comptime Error[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = C.Failure
    @staticmethod
    def apply[V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var observer: C, var source: V) raises C.Failure -> V:
        comptime assert Self.CarrierCompatible[V] and C.Payload == Self.Family[V].Failure
        comptime Native = Result[downcast[V,_ResultType].Value,Self.Family[V].Failure]
        return rebind_var[V](rebind_var[Native](source^).tap_err(observer^))


struct _TapErrSelection[I: Functor, V: Movable & Deinitable]:
    # Keep execution, carrier and native errors under one selected dictionary.
    # Recovery retains fail-constructor effects; mapping must target itself.
    comptime Recovering = conforms_to(Self.I,ApplicativeError)
    comptime Mapping = conforms_to(Self.I,ErrorMapping)
    comptime Supported = Self.Recovering or Self.Mapping or conforms_to(Self.V,_ResultType)
    comptime Input = downcast[Self.I,ApplicativeError].Failure if Self.Recovering else (downcast[Self.I,ErrorMapping].Failure if Self.Mapping else downcast[Self.V,_ResultType].Error)
    comptime Policy = downcast[_RecoveryTap[downcast[Self.I,ApplicativeError]] if Self.Recovering else (_MappingTap[downcast[Self.I,ErrorMapping]] if Self.Mapping else _IntrinsicTap),_TapErrPolicy]


struct TapErrContract[I: Functor, V: Movable & Deinitable,
                      C: BorrowCallContract & Movable & Deinitable]:
    """Admission, selected family and exact error of borrowed error observation.

    Forward Compatible and project Family, Out and Error in generic wrappers.
    Recovery families retain their failure-construction semantics. Mapping-only
    families borrow and retain the original error while targeting themselves.
    Families with neither capability retain legacy intrinsic Result observation.
    Callback results are discarded; native errors propagate at execution time.

    Parameters:
        I: The selected family.
        V: The complete source carrier, including origins.
        C: The borrowed-error observer and its exact native error.
    """
    comptime _Selection = _TapErrSelection[Self.I,Self.V]
    comptime _Policy = Self._Selection.Policy
    comptime CapabilityCompatible = Self._Selection.Supported
    """A selected error capability or legacy intrinsic Result is available."""
    comptime InputCompatible = Self.C.Payload == Self._Selection.Input if Self.CapabilityCompatible else False
    """Exact stored-error payload equality, including origins."""
    comptime CarrierCompatible = Self._Policy.CarrierCompatible[Self.V] if Self.CapabilityCompatible else False
    """The source belongs to the selected error channel."""
    comptime OutputCompatible = True
    """The observer result is discarded, so its type is unrestricted."""
    comptime FamilyCompatible = Self.CarrierCompatible
    """The selected source and observer output are admitted."""
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.C]
    """The observer supplies an invocable receiver."""
    comptime NativeErrorsCompatible = Self._Policy.NativeErrorsCompatible[Self.V,Self.C] if Self.InputCompatible and Self.FamilyCompatible else False
    """Recovery checks its fail error; mapping adds no failure-constructor error."""
    comptime OperationCompatible = Self._Policy.OperationCompatible[Self.V,Self.C] if Self.InputCompatible and Self.FamilyCompatible and Self.ReceiverCompatible and Self.NativeErrorsCompatible else False
    """The chosen primitive admits this observer and destination policy."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible and Self.ReceiverCompatible and Self.NativeErrorsCompatible and Self.OperationCompatible
    """Complete selected observation admission."""
    comptime Family = Self._Policy.Family[Self.V]
    """The selected family, or ResultFamily for legacy intrinsic observation."""
    comptime Handler = Self._Policy.Handler[Self.V,Self.C]
    """The adapted observation callback used by the selected primitive."""
    comptime Out = Self._Policy.Out[Self.V,Self.C]
    """The exact carrier, preserving deferred representation."""
    comptime Error = Self._Policy.Error[Self.V,Self.C]
    """The exact construction error; deferred errors remain in Out."""


comptime FlatTapErrContract[I: ApplicativeError, V: Movable & Deinitable,
                             C: BorrowCallContract & Movable & Deinitable] = _ErrorObserverContract[I,V,C,True]
"""Admission, output family and construction error of selected flat_tap_err.

Forward Compatible in generic selected-pipeline wrappers and project Family,
Out and Error. InputCompatible checks exact stored-error payload equality;
CarrierCompatible checks the source and OutputCompatible checks the observer's
returned carrier against the selected error layer. Its success payload may be
any type and is discarded. FamilyCompatible combines both carrier predicates.
OperationCompatible forwards the family's admission of the adapted observer;
NativeErrorsCompatible checks observer and failure-preservation errors. The
family owns accumulation, branching and deferred timing.

Parameters:
    I: The selected error family, including its error-combination policy.
    V: The complete source carrier, including origins.
    C: The borrowed-error observer returning a carrier in I.
"""


@always_inline
def _recover[I: ApplicativeError, V: Movable & Deinitable,
             H: UnaryContract & Movable & Deinitable](
    var handler: H, var source: V
) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    comptime C = RecoverContract[I,V,H]
    return I.or_else(C.Handler(handler^),source^)


@always_inline
def _or_else_if[I: ApplicativeError, V: Movable & Deinitable,
                P: BorrowCallContract & Movable & Deinitable,
                H: UnaryContract & Movable & Deinitable](
    var predicate: P, var handler: H, var source: V
) raises OrElseIfContract[I,V,P,H].Error -> OrElseIfContract[I,V,P,H].Out where OrElseIfContract[I,V,P,H].Compatible:
    comptime C = OrElseIfContract[I,V,P,H]
    return I.or_else(C.Continuation(predicate^,handler^),source^)


@always_inline
def _recover_if[I: ApplicativeError, V: Movable & Deinitable,
                P: BorrowCallContract & Movable & Deinitable,
                H: UnaryContract & Movable & Deinitable](
    var predicate: P, var handler: H, var source: V
) raises RecoverIfContract[I,V,P,H].Error -> RecoverIfContract[I,V,P,H].Out where RecoverIfContract[I,V,P,H].Compatible:
    comptime C = RecoverIfContract[I,V,P,H]
    return _or_else_if[I,V,P,C.Handler](predicate^,C.Handler(handler^),source^)


@always_inline
def _observe_error[I: ApplicativeError, V: Movable & Deinitable,
                   C: BorrowCallContract & Movable & Deinitable, effect: Bool](
    var observer: C, var source: V
) raises _ErrorObserverContract[I,V,C,effect].Error -> _ErrorObserverContract[I,V,C,effect].Out where _ErrorObserverContract[I,V,C,effect].Compatible:
    comptime Operation = _ErrorObserverContract[I,V,C,effect]
    return I.or_else(Operation.Handler(observer^),source^)


@always_inline
def _tap_err[I: Functor, V: Movable & Deinitable,
             C: BorrowCallContract & Movable & Deinitable](
    var observer: C, var source: V
) raises TapErrContract[I,V,C].Error -> TapErrContract[I,V,C].Out where TapErrContract[I,V,C].Compatible:
    return TapErrContract[I,V,C]._Policy.apply(observer^,source^)
