"""Selected recovery metadata; family and Result primitives own execution."""
from std.builtin.rebind import downcast, rebind_var
from fp.algebra.protocols import Functor, ApplicativeError, ErrorMapping
from fp.algebra.instances import ResultFamily
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.data._result import Result, _ResultType

comptime _RecoveryValue[V: Movable & Deinitable] = downcast[V, _ResultType].Value
comptime _RecoveryFailure[V: Movable & Deinitable] = downcast[V, _ResultType].Error
comptime _RecoveryCarrier[V: Movable & Deinitable] = (V == Result[_RecoveryValue[V], _RecoveryFailure[V]]) if conforms_to(V, _ResultType) else False

trait _OrElsePolicy:
    comptime CarrierCompatible[V: Movable & Deinitable]: Bool
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Bool
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Bool
    comptime Family[H: UnaryContract & Movable & Deinitable]: Functor
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.Error[V,H] -> Self.Out[V,H]: ...


struct _IntrinsicOrElse(_OrElsePolicy):
    comptime CarrierCompatible[V: Movable & Deinitable] = _RecoveryCarrier[V]
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = True
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = (H.Out == Result[_RecoveryValue[V], _RecoveryFailure[H.Out]]) if conforms_to(H.Out, _ResultType) else False
    comptime Family[H: UnaryContract & Movable & Deinitable] = ResultFamily[_RecoveryFailure[H.Out]]
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Out
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises H.Error -> H.Out:
        comptime assert H.Arg == _RecoveryFailure[V]
        return rebind_var[Result[_RecoveryValue[V],_RecoveryFailure[V]]](source^).or_else(handler^)


struct _FamilyOrElse[I: ApplicativeError](_OrElsePolicy):
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.I._ErrorCarrier[V]
    comptime OperationCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.I._Handles[V,H]
    comptime OutputCompatible[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.I._ErrorCarrier[H.Out] and Self.I.Element[V] == Self.I.Element[H.Out]
    comptime Family[H: UnaryContract & Movable & Deinitable] = Self.I
    comptime Out[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.I.Handled[V,H]
    comptime Error[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.I.HandleError[V,H]
    @staticmethod
    def apply[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.Error[V,H] -> Self.Out[V,H]:
        comptime assert Self.I._Handles[V,H]
        return Self.I.or_else(handler^,source^)


struct _RecoverySelection[I: Functor, V: Movable & Deinitable]:
    # Canonical Result and legacy intrinsic Result methods can change the
    # stored-error type. A custom family that selects an error channel needs
    # ApplicativeError for recovery; mapping alone does not permit fallback.
    comptime Intrinsic = ((not conforms_to(Self.I, ApplicativeError) and not conforms_to(Self.I, ErrorMapping)) or Self.I == ResultFamily[_RecoveryFailure[Self.V]]) if conforms_to(Self.V, _ResultType) else False
    comptime Supported = Self.Intrinsic or conforms_to(Self.I, ApplicativeError)
    comptime Policy = downcast[_IntrinsicOrElse if Self.Intrinsic else _FamilyOrElse[downcast[Self.I,ApplicativeError]], _OrElsePolicy]
    comptime Input = _RecoveryFailure[Self.V] if Self.Intrinsic else downcast[Self.I,ApplicativeError].Failure


struct OrElseContract[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]:
    """Admission, result family and exact error of selected Pipeline.or_else.

    Canonical Result pipelines may change their stored-error type. Other
    ApplicativeError families retain their selected error layer and execution
    semantics. Legacy intrinsic Result calls under non-error families preserve
    their Result behavior. Generic selected wrappers can forward Compatible
    and project Family, Out and Error without deciding which case applies.

    Parameters:
        I: The selected source family.
        V: The complete source carrier, including origins.
        H: The library handler consuming the stored error and returning a carrier.
    """
    comptime _Selection = _RecoverySelection[Self.I, Self.V]
    comptime Input = Self._Selection.Input
    """The selected stored-error payload, fixed before native callback inference."""
    comptime InputCompatible = (Self.H.Arg == Self.Input) if Self._Selection.Supported else False
    """Exact handler input equality, including origins."""
    comptime CarrierCompatible = Self._Selection.Supported and Self._Selection.Policy.CarrierCompatible[Self.V]
    """The source belongs to the selected recovery policy."""
    comptime OutputCompatible = Self._Selection.Supported and Self._Selection.Policy.OutputCompatible[Self.V,Self.H]
    """Intrinsic Result permits a new error; other families retain their error layer."""
    comptime ReceiverCompatible = _OnceUnaryAvailable[Self.H]
    """The handler supplies an invocable receiver before policy execution."""
    comptime OperationCompatible = Self._Selection.Policy.OperationCompatible[Self.V,Self.H] if Self.InputCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.ReceiverCompatible else False
    """The selected policy admits the handler; custom families retain their rules."""
    comptime Compatible = Self.InputCompatible and Self.CarrierCompatible and Self.OutputCompatible and Self.ReceiverCompatible and Self.OperationCompatible
    """Complete selected recovery admission, including the declared family operation."""
    comptime Family = Self._Selection.Policy.Family[Self.H]
    """The output family for fluent continuation."""
    comptime Out = Self._Selection.Policy.Out[Self.V, Self.H]
    """The exact recovered carrier, including deferred representations."""
    comptime Error = Self._Selection.Policy.Error[Self.V, Self.H]
    """The exact construction error; deferred run errors remain with the carrier."""


@always_inline
def _selected_or_else[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises OrElseContract[I,V,H].Error -> OrElseContract[I,V,H].Out where OrElseContract[I,V,H].Compatible:
    return OrElseContract[I,V,H]._Selection.Policy.apply(handler^,source^)
