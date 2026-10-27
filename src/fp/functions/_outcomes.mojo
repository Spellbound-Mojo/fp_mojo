"""Selected outcome metadata; existing Result and family primitives execute it."""
from std.builtin.rebind import downcast, rebind_var
from fp._internal.errors import _CommonError
from fp.algebra.protocols import Functor, ApplicativeError, Monad, _MappedFamily
from fp.algebra.instances import ResultFamily
from fp.algebra._outcomes import _Redeem
from fp.callables.protocols import UnaryContract
from fp.data._result import Result
from ._recovery import _RecoverySelection, _RecoveryValue, _RecoveryFailure, _RecoveryCarrier


trait _OutcomePolicy:
    comptime CarrierCompatible[V: Movable & Deinitable]: Bool
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable]: Bool
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable]: Bool
    comptime Family[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable]: Functor
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source: V, var on_ok: H, var on_err: K) raises Self.Error[V,H,K] -> Self.Out[V,H,K]: ...


struct _IntrinsicOutcome[effect: Bool](_OutcomePolicy):
    comptime CarrierCompatible[V: Movable & Deinitable] = _RecoveryCarrier[V]
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = (H.Out == K.Out and _RecoveryCarrier[H.Out]) if Self.effect else H.Out == K.Out
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = True
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = H.Out if Self.effect else Result[H.Out, _RecoveryFailure[V]]
    comptime Family[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = ResultFamily[_RecoveryFailure[Self.Out[V,H,K]]]
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = _CommonError[H.Error, K.Error]
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source: V, var on_ok: H, var on_err: K) raises Self.Error[V,H,K] -> Self.Out[V,H,K]:
        comptime assert Self.CarrierCompatible[V] and Self.OutputCompatible[V,H,K]
        comptime assert H.Arg == _RecoveryValue[V] and K.Arg == _RecoveryFailure[V]
        comptime assert H.Out == K.Out and (H.Error == Never or K.Error == Never or H.Error == K.Error)
        var value = rebind_var[Result[_RecoveryValue[V],_RecoveryFailure[V]]](source^)
        comptime if Self.effect:
            comptime assert Self.Out[V,H,K] == H.Out
            return rebind_var[Self.Out[V,H,K]](value^.redeem_with(on_ok^,on_err^))
        else:
            comptime assert Self.Out[V,H,K] == Result[H.Out,_RecoveryFailure[V]]
            return rebind_var[Self.Out[V,H,K]](value^.redeem(on_ok^,on_err^))


struct _FamilyOutcome[I: ApplicativeError, effect: Bool](_OutcomePolicy):
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.I._ErrorCarrier[V]
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = (Self.I._ErrorCarrier[H.Out] and Self.I._ErrorCarrier[K.Out] and Self.I.Element[H.Out] == Self.I.Element[K.Out]) if Self.effect else H.Out == K.Out
    comptime _Operation[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = _Redeem[Self.I,V,H,K,Self.effect]
    # Admit the same operations the existing execution owner performs. Custom
    # primitives may rely on these predicates without reasserting them in-body.
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = Self._Operation[V,H,K].OperationCompatible
    comptime Family[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = Self.I if Self.effect else _MappedFamily[Self.I,H.Out]
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = Self._Operation[V,H,K].Out
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable] = Self._Operation[V,H,K].Error
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source: V, var on_ok: H, var on_err: K) raises Self.Error[V,H,K] -> Self.Out[V,H,K]:
        return _Redeem[Self.I,V,H,K,Self.effect].apply(source^,on_ok^,on_err^)


struct _OutcomeSelection[I: Functor, V: Movable & Deinitable, effect: Bool]:
    # Share recovery's canonical-vs-custom decision. Selection precedes callback
    # inference; output stored-error equality never chooses an overload.
    comptime Recovery = _RecoverySelection[Self.I,Self.V]
    comptime Intrinsic = Self.Recovery.Intrinsic
    comptime Supported = Self.Recovery.Supported and (not Self.effect or Self.Intrinsic or conforms_to(Self.I,Monad))
    comptime Success = _RecoveryValue[Self.V] if Self.Intrinsic else Self.I.Element[Self.V]
    comptime Failure = Self.Recovery.Input
    comptime Policy = downcast[_IntrinsicOutcome[Self.effect] if Self.Intrinsic else _FamilyOutcome[downcast[Self.I,ApplicativeError],Self.effect], _OutcomePolicy]


struct _OutcomeContract[I: Functor, V: Movable & Deinitable,
                        H: UnaryContract & Movable & Deinitable,
                        K: UnaryContract & Movable & Deinitable, effect: Bool]:
    comptime _Selection = _OutcomeSelection[Self.I,Self.V,Self.effect]
    comptime InputCompatible = (Self.H.Arg == Self._Selection.Success and Self.K.Arg == Self._Selection.Failure) if Self._Selection.Supported else False
    """Both handlers consume the exact selected payload types and origins."""
    comptime CarrierCompatible = Self._Selection.Supported and Self._Selection.Policy.CarrierCompatible[Self.V]
    """The source belongs to the selected outcome policy."""
    comptime OutputCompatible = Self._Selection.Supported and Self._Selection.Policy.OutputCompatible[Self.V,Self.H,Self.K]
    """Handlers agree on a value type or produce compatible selected effects."""
    comptime NativeErrorsCompatible = Self.H.Error == Never or Self.K.Error == Never or Self.H.Error == Self.K.Error
    """The callbacks share a native error type or at least one cannot raise."""
    comptime OperationCompatible = Self._Selection.Supported and Self._Selection.Policy.OperationCompatible[Self.V,Self.H,Self.K]
    """The selected family admits materialization and the final map or bind."""
    comptime Compatible = Self.InputCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.NativeErrorsCompatible and Self.OperationCompatible
    """Selected admission; existing family primitives retain invocation checks."""
    comptime Family = Self._Selection.Policy.Family[Self.V,Self.H,Self.K]
    """The output family for fluent continuation."""
    comptime Out = Self._Selection.Policy.Out[Self.V,Self.H,Self.K]
    """The exact outcome carrier, including deferred representations."""
    comptime Error = Self._Selection.Policy.Error[Self.V,Self.H,Self.K]
    """The exact construction error; deferred run errors remain with the carrier."""


comptime RedeemContract[I: Functor, V: Movable & Deinitable,
                       H: UnaryContract & Movable & Deinitable,
                       K: UnaryContract & Movable & Deinitable] = _OutcomeContract[I,V,H,K,False]
"""Admission and result metadata for selected value-returning outcome handling.

Forward Compatible and project Family, Out and Error in a generic wrapper of
Pipeline.redeem. One handler consumes the original selected outcome; its native
error is never sent to the other handler. ApplicativeError suffices for family
execution, including Validation. Intrinsic Result behavior remains available
under non-error families. Mapping rebinds the output family where supported.

Parameters:
    I: The selected source family.
    V: The complete source carrier, including origins.
    H: The consuming success handler.
    K: The consuming stored-error handler, returning the same value type.
"""


comptime RedeemWithContract[I: Functor, V: Movable & Deinitable,
                           H: UnaryContract & Movable & Deinitable,
                           K: UnaryContract & Movable & Deinitable] = _OutcomeContract[I,V,H,K,True]
"""Admission and result metadata for selected effect-returning outcome handling.

Forward Compatible and project Family, Out and Error in a generic wrapper of
Pipeline.redeem_with. Canonical and intrinsic Result handlers may agree on a new
stored-error type. Other selected families require ApplicativeError and Monad,
retaining their own error layer and execution semantics. Returned failures and
native raises never invoke the opposite handler.

Parameters:
    I: The selected source family.
    V: The complete source carrier, including origins.
    H: The consuming success handler producing a replacement effect.
    K: The consuming stored-error handler producing a compatible effect.
"""


@always_inline
def _selected_redeem[I: Functor, V: Movable & Deinitable,
                     H: UnaryContract & Movable & Deinitable,
                     K: UnaryContract & Movable & Deinitable, effect: Bool](
    var source: V, var on_ok: H, var on_err: K
) raises _OutcomeContract[I,V,H,K,effect].Error -> _OutcomeContract[I,V,H,K,effect].Out where _OutcomeContract[I,V,H,K,effect].Compatible:
    return _OutcomeContract[I,V,H,K,effect]._Selection.Policy.apply(source^,on_ok^,on_err^)
