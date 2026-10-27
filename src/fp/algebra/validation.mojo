"""Accumulating Result validation using the existing Applicative machinery."""
from std.builtin.rebind import downcast, rebind_var
from .protocols import Semigroup, ApplicativeError, ErrorMapping, _Accumulate, _LinearProducerCompatible
from .instances import ResultFamily, _ListElement
from .monoids import ListMonoid
from ._result_accumulation import _result_map2, _AccumulatingErrors, _result_loop, _ResultLoopCompatible
from fp.data._result import Result, _ResultType
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp._internal.errors import _CommonError


# Inference is deliberately restricted to native list-valued stored errors.
# Signature admission also checks the exact carrier; downcast alone does not
# distinguish nested origins in Mojo 1.1.
comptime _ListErrors[V: Movable & Deinitable] = ListMonoid[_ListElement[downcast[V, _ResultType].Error]]


trait _ValidationPolicy:
    comptime _ErrorSemigroup: Semigroup


struct ValidationFamily[S: Semigroup](ApplicativeError, ErrorMapping, _ValidationPolicy):
    """Native Result with ordered error accumulation for independent operations.

    Both failed operands combine their stored errors with S. Native raises
    still stop immediately. This is an alternative Applicative, not a Monad;
    Result's own dependent flat_map continues to use its usual short circuit.
    No threads are started and no runtime wrapper or error conversion is added.

    Parameters:
        S: The associative error combiner; its Value is the exact stored error
            type. ListMonoid concatenates list errors in input order.
    """
    comptime _ErrorSemigroup = Self.S
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable] = Self
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = ResultFamily[Self.S.Value].ErrorCarrierCompatible[V]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = (
        (Target == ValidationFamily[downcast[Target,_ValidationPolicy]._ErrorSemigroup] and ResultFamily[Self.S.Value].BimapCompatible[ResultFamily[G.Out],V,F,G])
        if conforms_to(Target,_ValidationPolicy) else False
    )
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = ResultFamily[Self.S.Value].Bimapped[ResultFamily[G.Out],V,F,G]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = ResultFamily[Self.S.Value].BimapError[ResultFamily[G.Out],V,F,G]
    comptime Element[V: Movable & Deinitable] = ResultFamily[Self.S.Value].Element[V]
    comptime Failure = Self.S.Value
    comptime CarrierCompatible[V: Movable & Deinitable] = ResultFamily[Self.S.Value].CarrierCompatible[V]
    comptime _ErrorCarrier[V: Movable & Deinitable] = ResultFamily[Self.S.Value]._ErrorCarrier[V]
    # Validation changes error accumulation, not the native Result carrier.
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ResultFamily[Self.S.Value].MapCompatible[V, F]
    """Use the Result family's exact stored-error and origin admission for mapping."""
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = ResultFamily[Self.S.Value].CombineCompatible[V, F, R]
    """Use the Result family's carrier and payload admission before combining errors."""
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _ResultLoopCompatible[V, F, K, Self.S.Value, Self.S.Error]
    # Both predicates guard their own projections. Eager Boolean composition
    # preserves caller evidence for the carrier and exact native error.
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out] & _LinearProducerCompatible[V, F, Self.S.Error]
    """Require a repeatable producer with the selected Result carrier and compatible native errors."""
    comptime Failed[A: Movable & Deinitable] = ResultFamily[Self.S.Value].Failed[A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = ResultFamily[Self.S.Value].Handled[V, H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Result[F.Out, Self.S.Value]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Result[A, Self.S.Value]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Result[F.Out, Self.S.Value]
    # A non-raising policy leaves a generic callback error unchanged. This
    # ordering preserves the existing native error spelling on Mojo 1.1.
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[Self.S.Error, _CommonError[F.Error, R.Error]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Result[K.Acc, Self.S.Value]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[Self.S.Error, _CommonError[F.Error, K.Error]]

    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](
        var on_ok: F, var on_err: G, var source: V
    ) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        """Map the accumulated error once, preserving the chosen target policy.

        Parameters:
            Target: The admitted ValidationFamily and destination Semigroup.
            V: The source Result type.
            F: The consuming success callback type.
            G: The consuming accumulated-error callback type.

        Args:
            on_ok: The callback selected by an original success.
            on_err: The callback selected by an original accumulated error.
            source: The validation carrier, consumed once.

        Returns:
            The transformed Result; no Semigroup combine operation runs.

        Raises:
            The selected callback's exact native error.
        """
        return ResultFamily[Self.S.Value].bimap[ResultFamily[G.Out]](on_ok^,on_err^,source^)

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) -> Self.Failed[A]:
        """Construct a stored validation failure through ResultFamily.

        Parameters:
            A: The absent success payload type.

        Args:
            error: The stored error, consumed with its exact type and origins.

        Returns:
            A native Err carrying the supplied error.
        """
        return ResultFamily[Self.S.Value].fail[A](error^)

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        """Recover the accumulated stored error through ResultFamily.

        Parameters:
            V: The source Result type.
            H: The handler consuming the stored error and returning the same
                Result success and error types.

        Args:
            handler: The handler, consumed and skipped on success.
            source: The Result, consumed.

        Returns:
            The original success or the handler's Result.

        Raises:
            The exact native error raised by the handler.
        """
        return ResultFamily[Self.S.Value].or_else(handler^, source^)

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Transform a success through the canonical Result mapping.

        Parameters:
            V: The Result carrier type.
            F: The callback type.

        Args:
            f: The callback, consumed.
            value: The Result, consumed.

        Returns:
            A transformed success or the original stored error.

        Raises:
            The callback's exact native error.
        """
        return ResultFamily[Self.S.Value].map(f^, value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Introduce a successful validation.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            Ok(value) with S.Value as its stored error type.
        """
        return ResultFamily[Self.S.Value].pure(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Force the right operand once, combining successes or accumulating errors.

        Parameters:
            V: The left Result type.
            F: The success combiner type.
            R: The right Result thunk type.

        Args:
            f: The callback, consumed; called only for two successes.
            left: The left Result, consumed.
            right: The thunk, consumed and called even after a stored left error.

        Returns:
            The combined success, the single error, or S.combine(left, right)
            when both operands fail. An empty error list is still a failure.

        Raises:
            The exact native callback, thunk or Semigroup error.
        """
        comptime assert V == Result[F.First, Self.S.Value]
        return _result_map2[Self.S.Value, P=_AccumulatingErrors[Self.S], X=Self.CombineError[V, F, R]](
            f^, rebind_var[Result[F.First, Self.S.Value]](left^), right^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return _result_loop[V, F, K, _AccumulatingErrors[Self.S], Self._LoopError[V, F, K]](f^, source^)
