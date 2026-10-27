"""Validation and outcome composition derived from existing family operations."""

from std.builtin.rebind import downcast, rebind_var
from fp._internal.errors import _CommonError, _ErrorCompatible
from fp.callables.protocols import Unary, UnaryContract, OnceUnary, MutableUnary, BorrowCallContract
from fp.callables.invoke import RepeatableUnary
from fp.callables._receiver import _OnceBorrowAvailable, _RepeatableBorrow, _MutableBorrowRef, _MutableUnaryRef, _unary_once_as, _borrow_once_as
from fp.callables._conditional import _guard_owned
from fp.data._result import Result, _transformed, _fold_result_owned
from .protocols import _pure, Applicative, ApplicativeError, Monad
from ._primitive_contracts import MapContract, BindContract
from ._adapt import _fail_as, _map_as, _or_else_as, _flat_map_as
from .errors import _Recovered
from ._sequencing import _EffectRetain

comptime _ErrorMonad[I: Applicative] = downcast[I, ApplicativeError & Monad]


struct EnsureContract[I: ApplicativeError & Monad, V: Movable & Deinitable,
                      P: BorrowCallContract & Movable & Deinitable,
                      G: BorrowCallContract & Movable & Deinitable]:
    """Admission, output and exact construction error of family-based ensure.

    A generic selected-pipeline wrapper forwards Compatible and projects
    Family, Out and Error without naming the private validation continuation.
    Both callbacks borrow successes. Existing stored failures skip them; the
    error factory runs only after the predicate rejects a success. Families
    retain their native timing, receiver validation and branching semantics.

    Parameters:
        I: The selected Monad with a stored-error capability.
        V: The complete consumed source carrier, including origins.
        P: The borrowing Bool predicate.
        G: The borrowing factory producing I.Failure.
    """
    comptime Continuation = _Ensure[Self.I, Self.I.Element[Self.V], Self.P, Self.G]
    """The existing validation continuation supplied to family bind."""
    comptime InputCompatible = Self.P.Payload == Self.I.Element[Self.V] and Self.G.Payload == Self.I.Element[Self.V]
    """Both callbacks borrow the exact success payload, including origins."""
    comptime PredicateCompatible = Self.P.Result == Bool
    """The predicate produces the native Bool type."""
    comptime FailureCompatible = Self.G.Result == Self.I.Failure
    """The factory produces the exact selected stored-error type and origins."""
    comptime CarrierCompatible = Self.I._ErrorCarrier[Self.V]
    """The source belongs to the selected stored-error layer."""
    comptime CallbackErrorsCompatible = Self.P.Failure == Never or Self.G.Failure == Never or Self.P.Failure == Self.G.Failure
    """The callbacks share an exact native error type or cannot raise."""
    comptime _Bind = BindContract[Self.I, Self.V, Self.Continuation]
    comptime BindCompatible = Self._Bind.FamilyCompatible
    """The selected family's admission of the existing validation continuation."""
    comptime Compatible = Self.InputCompatible and Self.PredicateCompatible and Self.FailureCompatible and Self.CarrierCompatible and Self.CallbackErrorsCompatible and Self.BindCompatible
    """Selected ensure admission; legacy Piped keeps its original predicates."""
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.P] and _OnceBorrowAvailable[Self.G]
    """Both borrowed callbacks have a shared or consuming receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing admission plus receiver availability for new wrapper boundaries."""
    comptime Family = Self.I
    """The unchanged family for fluent continuation."""
    comptime Out = Self._Bind.Out
    """The family's exact validated carrier, including deferred representations."""
    comptime Error = Self._Bind.Error
    """The native construction error; deferred run errors remain with the carrier."""


@fieldwise_init
struct _Ensure[I: ApplicativeError, A: Movable & Deinitable,
               C: BorrowCallContract & Movable & Deinitable,
               G: BorrowCallContract & Movable & Deinitable](
    OnceUnary, MutableUnary where _RepeatableBorrow[C] and _RepeatableBorrow[G]
):
    var predicate: Self.C
    var make_error: Self.G
    comptime Arg = Self.A
    comptime Out = Self.I._Joined[Self.I.Pure[Self.A], Self.I.Failed[Self.A]]
    comptime Error = _CommonError[Self.C.Failure, _CommonError[Self.G.Failure, Self.I.FailError[Self.A]]]
    def call_once(deinit self, var arg: Self.A) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.A and Self.C.Result == Bool
        comptime assert Self.G.Payload == Self.A and Self.G.Result == Self.I.Failure
        comptime assert _ErrorCompatible[Self.Error, Self.G.Failure] and _ErrorCompatible[Self.Error, Self.I.FailError[Self.A]], "ensure: incompatible native errors"
        def keep(var value: Self.A) raises Self.Error capturing -> Self.Out:
            return Self.I._join_left[Self.I.Pure[Self.A], Self.I.Failed[Self.A]](_pure[Self.I](value^))
        def reject(var value: Self.A, var factory: Self.G) raises Self.Error capturing -> Self.Out:
            var error = _borrow_once_as[Self.Error](value, factory^)
            return Self.I._join_right[Self.I.Pure[Self.A], Self.I.Failed[Self.A]](
                _fail_as[Self.Error, Self.I, Self.A](rebind_var[Self.I.Failure](error^)))
        return _guard_owned[Self.A, Self.C, Self.G, Self.Out, Self.Error, False, keep, reject](arg^, self.predicate^, self.make_error^)
    def call_mut(mut self, var arg: Self.A) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C] and _RepeatableBorrow[Self.G], "ensure: branching requires repeatable callbacks"
        var predicate = _MutableBorrowRef(Pointer(to=self.predicate))
        var factory = _MutableBorrowRef(Pointer(to=self.make_error))
        return _Ensure[Self.I, Self.A, type_of(predicate), type_of(factory)](predicate^, factory^).call_once(arg^)


@fieldwise_init
struct _OutcomeCase[A: Movable & Deinitable, E: Movable & Deinitable, success: Bool](Unary, Copyable, Defaultable):
    comptime Arg = Self.A if Self.success else Self.E
    comptime Out = Result[Self.A, Self.E]
    def call(self, var arg: Self.Arg) -> Self.Out:
        return _transformed[Self.A, Self.E, Self.Arg, Self.success, True](arg^)


struct _Materialize[I: ApplicativeError, V: Movable & Deinitable]:
    """Expose only the selected stored outcome as a successful native Result."""
    comptime A = Self.I.Element[Self.V]
    comptime Wrap = _OutcomeCase[Self.A, Self.I.Failure, True]
    comptime Recover = _Recovered[Self.I, _OutcomeCase[Self.A, Self.I.Failure, False]]
    comptime _Map = MapContract[Self.I, Self.V, Self.Wrap]
    comptime Mapped = Self._Map.Out
    comptime MapCompatible = Self._Map.FamilyCompatible
    comptime HandleCompatible = Self.I._Handles[Self.Mapped, Self.Recover]
    comptime Out = Self.I.Handled[Self.Mapped, Self.Recover]
    comptime Error = _CommonError[Self._Map.Error, Self.I.HandleError[Self.Mapped, Self.Recover]]
    @staticmethod
    def apply[X: Movable & Deinitable](var source: Self.V) raises X -> Self.Out:
        comptime assert _ErrorCompatible[X, Self.I.MapError[Self.V, Self.Wrap]]
        comptime assert _ErrorCompatible[X, Self.I.HandleError[Self.Mapped, Self.Recover]]
        comptime assert Self.I._Handles[Self.Mapped, Self.Recover]
        var wrapped = _map_as[X, Self.I](Self.Wrap(), source^)
        return _or_else_as[X, Self.I](Self.Recover(_OutcomeCase[Self.A, Self.I.Failure, False]()), wrapped^)


def _outcome_arm[I: ApplicativeError, L: Movable & Deinitable, R: Movable & Deinitable,
                 effect: Bool, left: Bool, H: UnaryContract & Movable & Deinitable,
                 P: Movable & Deinitable, O: Movable & Deinitable](
    var payload: P, var handler: H
) raises H.Error capturing -> O:
    comptime assert P == H.Arg and O == (I._Joined[L, R] if effect else L)
    var value = _unary_once_as[H.Error](handler^, rebind_var[H.Arg](payload^))
    comptime if effect:
        comptime assert H.Out == (L if left else R)
        comptime if left:
            return rebind_var[O](I._join_left[L, R](rebind_var[L](value^)))
        else:
            return rebind_var[O](I._join_right[L, R](rebind_var[R](value^)))
    else:
        comptime assert H.Out == L
        return rebind_var[O](value^)


@fieldwise_init
struct _OutcomeFold[I: ApplicativeError, A: Movable & Deinitable,
                    H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable,
                    effect: Bool](OnceUnary, MutableUnary where RepeatableUnary[H] and RepeatableUnary[K]):
    var on_ok: Self.H
    var on_err: Self.K
    comptime Arg = Result[Self.A, Self.I.Failure]
    comptime Out = Self.I._Joined[Self.H.Out, Self.K.Out] if Self.effect else Self.H.Out
    comptime Error = _CommonError[Self.H.Error, Self.K.Error]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.H.Arg == Self.A and Self.K.Arg == Self.I.Failure
        comptime assert _ErrorCompatible[Self.Error, Self.H.Error] and _ErrorCompatible[Self.Error, Self.K.Error], "outcome: incompatible native errors"
        # Result owns branch selection, disposal of the inactive handler and
        # native error propagation. No new branch interpreter lives here.
        return _fold_result_owned[Self.A, Self.I.Failure, Self.Out, Self.Error, Self.H.Error, Self.K.Error, Self.H, Self.K,
            _outcome_arm[Self.I, Self.H.Out, Self.K.Out, Self.effect, True, Self.H, Self.A, Self.Out],
            _outcome_arm[Self.I, Self.H.Out, Self.K.Out, Self.effect, False, Self.K, Self.I.Failure, Self.Out]](arg^, self.on_ok^, self.on_err^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.H] and RepeatableUnary[Self.K], "outcome: branching requires repeatable handlers"
        var left = _MutableUnaryRef(Pointer(to=self.on_ok))
        var right = _MutableUnaryRef(Pointer(to=self.on_err))
        return _OutcomeFold[Self.I, Self.A, type_of(left), type_of(right), Self.effect](left^, right^).call_once(arg^)


struct _Redeem[I: ApplicativeError, V: Movable & Deinitable,
               H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable, effect: Bool]:
    comptime Capture = _Materialize[Self.I, Self.V]
    comptime Fold = _OutcomeFold[Self.I, Self.I.Element[Self.V], Self.H, Self.K, Self.effect]
    comptime M = downcast[Self.I, Monad]
    comptime _Map = MapContract[Self.I, Self.Capture.Out, Self.Fold]
    comptime _Bind = BindContract[Self.M, Self.Capture.Out, Self.Fold]
    comptime OperationCompatible = Self.Capture.MapCompatible and Self.Capture.HandleCompatible and (Self._Bind.FamilyCompatible if Self.effect else Self._Map.FamilyCompatible)
    comptime Out = Self._Bind.Out if Self.effect else Self._Map.Out
    comptime StepError = Self._Bind.Error if Self.effect else Self._Map.Error
    comptime Error = _CommonError[Self.Capture.Error, Self.StepError]
    @staticmethod
    def apply(var source: Self.V, var on_ok: Self.H, var on_err: Self.K) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.Capture.Error] and _ErrorCompatible[Self.Error, Self.StepError], "outcome: incompatible native errors"
        var captured = Self.Capture.apply[Self.Error](source^)
        var fold = Self.Fold(on_ok^, on_err^)
        comptime if Self.effect:
            comptime assert _ErrorCompatible[Self.Error, Self.M.BindError[Self.Capture.Out, Self.Fold]]
            comptime assert Self.Out == Self.M.Bound[Self.Capture.Out, Self.Fold]
            return rebind_var[Self.Out](_flat_map_as[Self.Error, Self.M](fold^, captured^))
        else:
            comptime assert _ErrorCompatible[Self.Error, Self.I.MapError[Self.Capture.Out, Self.Fold]]
            comptime assert Self.Out == Self.I.Mapped[Self.Capture.Out, Self.Fold]
            return rebind_var[Self.Out](_map_as[Self.Error, Self.I](fold^, captured^))


@fieldwise_init
struct _Restore[I: ApplicativeError, A: Movable & Deinitable](Unary, Copyable, Defaultable):
    comptime Arg = Result[Self.A, Self.I.Failure]
    comptime Out = Self.I._Joined[Self.I.Pure[Self.A], Self.I.Failed[Self.A]]
    comptime Error = Self.I.FailError[Self.A]
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        def success(var value: Self.A, var unused: NoneType) raises Never capturing -> Self.Out:
            return Self.I._join_left[Self.I.Pure[Self.A], Self.I.Failed[Self.A]](_pure[Self.I](value^))
        def failure(var error: Self.I.Failure, var unused: NoneType) raises Self.Error capturing -> Self.Out:
            return Self.I._join_right[Self.I.Pure[Self.A], Self.I.Failed[Self.A]](Self.I.fail[Self.A](error^))
        return _fold_result_owned[Self.A, Self.I.Failure, Self.Out, Self.Error, Never, Self.Error,
            NoneType, NoneType, success, failure](arg^, NoneType(), NoneType())


struct _AttemptTap[I: ApplicativeError & Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]:
    comptime Capture = _Materialize[Self.I, Self.V]
    comptime Outcome = Result[Self.I.Element[Self.V], Self.I.Failure]
    comptime Retain = _EffectRetain[Self.Outcome, Self.I, Self.C]
    comptime _ObserveOperation = BindContract[Self.I, Self.Capture.Out, Self.Retain]
    comptime Observed = Self._ObserveOperation.Out
    comptime Restore = _Restore[Self.I, Self.I.Element[Self.V]]
    comptime _RestoreOperation = BindContract[Self.I, Self.Observed, Self.Restore]
    comptime Out = Self._RestoreOperation.Out
    comptime Error = _CommonError[Self.Capture.Error, _CommonError[Self._ObserveOperation.Error, Self._RestoreOperation.Error]]
    @staticmethod
    def apply(var source: Self.V, var inspect: Self.C) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.Capture.Error]
        comptime assert _ErrorCompatible[Self.Error, Self.I.BindError[Self.Capture.Out, Self.Retain]] and _ErrorCompatible[Self.Error, Self.I.BindError[Self.Observed, Self.Restore]], "attempt_tap: incompatible native errors"
        var captured = Self.Capture.apply[Self.Error](source^)
        var observed = _flat_map_as[Self.Error, Self.I](Self.Retain(inspect^), captured^)
        return _flat_map_as[Self.Error, Self.I](Self.Restore(), observed^)


struct AttemptTapContract[I: ApplicativeError & Monad, V: Movable & Deinitable,
                          C: BorrowCallContract & Movable & Deinitable]:
    """Admission and exact result of observing a selected whole stored outcome.

    The observer borrows Result[Element[V], Failure] on either stored branch
    and returns an effect in I. Successful observer branches restore the
    original outcome; observer failures replace it and empty effects stay
    empty. Generic selected wrappers forward Compatible and project Family,
    Out and Error. Existing primitives retain receiver, copying and join checks.

    Parameters:
        I: The selected Monad with a stored-error capability.
        V: The complete consumed source carrier, including origins.
        C: The borrowing whole-outcome observer returning an effect in I.
    """
    comptime _Plan = _AttemptTap[Self.I, Self.V, Self.C]
    comptime Outcome = Self._Plan.Outcome
    """The exact native Result borrowed by the observer, including origins."""
    comptime InputCompatible = Self.C.Payload == Self.Outcome
    """The observer borrows the selected complete stored outcome."""
    comptime SourceCompatible = Self.I._ErrorCarrier[Self.V]
    """The input belongs to the selected stored-error layer."""
    comptime ObserverCompatible = Self.I._ErrorCarrier[Self.C.Result]
    """The observer produces a carrier in the selected stored-error layer."""
    comptime MaterializeMapCompatible = Self._Plan.Capture.MapCompatible
    """Family map admission for exposing each success as a native Result."""
    comptime MaterializeHandleCompatible = Self._Plan.Capture.HandleCompatible
    """Family recovery admission for exposing each selected failure."""
    comptime ObserveBindCompatible = Self._Plan._ObserveOperation.FamilyCompatible
    """Family bind admission for observing and retaining the native outcome."""
    comptime RestoreBindCompatible = Self._Plan._RestoreOperation.FamilyCompatible
    """Family bind admission for restoring each retained outcome."""
    comptime FamilyCompatible = Self.SourceCompatible and Self.ObserverCompatible and Self.MaterializeMapCompatible and Self.MaterializeHandleCompatible and Self.ObserveBindCompatible and Self.RestoreBindCompatible
    """Carrier and primitive admission without repeating callback input equality."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """Selected entry-point admission; receiver and copy checks remain with families."""
    comptime ReceiverCompatible = _OnceBorrowAvailable[Self.C]
    """The whole-outcome observer has a shared or consuming receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing admission plus receiver availability for new wrapper boundaries."""
    comptime Family = Self.I
    """The unchanged family for fluent continuation."""
    comptime Out = Self._Plan.Out
    """The exact observed/restored carrier, including deferred representations."""
    comptime Error = Self._Plan.Error
    """The exact construction error; deferred callback and restoration errors remain deferred."""
