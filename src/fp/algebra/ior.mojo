"""Explicit sequential and accumulating policies for inclusive-or values."""
from std.builtin.rebind import downcast, rebind_var
from fp.adt.data import _ChoiceType
from fp.data.ior import Ior, Left, Right, Both, _IorData, _ior_parts, _ior_from_parts
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp.callables.invoke import call_once
from fp.callables._receiver import _unary_once_as, _binary_once_as, _thunk_once_as
from fp.callables._transforms import _ValueThunk
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import (Applicative, Monad, Semigroup, _Accumulate, _combine_as,
                        _AccumulatePair, _map_accumulate, _start_as)
from ._accumulation import _OptionalCombine


comptime _IorDiagnostics[V: Movable & Deinitable] = downcast[downcast[V, _ChoiceType].Of, _IorData].Diagnostics
comptime _IorElement[V: Movable & Deinitable] = downcast[downcast[V, _ChoiceType].Of, _IorData].Payload


# Put a literal non-raising policy first, so generic native callback errors
# remain unconstrained instead of an unreduced "E is Never or True" predicate.
comptime _IorErrors[A: Movable & Deinitable, B: Movable & Deinitable] = True if A == Never else _ErrorCompatible[A, B]


def _ior_merge[S: Semigroup, X: Movable & Deinitable](
    var earlier: Optional[S.Value], var later: Optional[S.Value]
) raises X -> Optional[S.Value]:
    """Combine present diagnostics in order; absence never requires an identity."""
    comptime assert _ErrorCompatible[X, S.Error]
    if not later:
        return earlier^
    return _combine_as[X, _OptionalCombine[S]](earlier^, later.unsafe_take())


def _ior_map[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var source: Ior[E, F.Arg]
) raises F.Error -> Ior[E, F.Out]:
    var diagnostics = Optional[E]()
    var payload = Optional[F.Arg]()
    _ior_parts(source^).split(diagnostics, payload)
    var mapped = Optional[F.Out]()
    if payload:
        mapped = Optional(call_once(f^, payload.unsafe_take()))
    return _ior_from_parts(diagnostics^, mapped^)


def _ior_bind[S: Semigroup, F: UnaryContract & Movable & Deinitable, X: Movable & Deinitable](
    var f: F, var source: Ior[S.Value, F.Arg]
) raises X -> Ior[S.Value, _IorElement[F.Out]]:
    comptime B = _IorElement[F.Out]
    comptime assert F.Out == Ior[S.Value, B], "flat_map: callback must return the same Ior diagnostic type"
    comptime assert _ErrorCompatible[X, F.Error]
    var diagnostics = Optional[S.Value]()
    var payload = Optional[F.Arg]()
    _ior_parts(source^).split(diagnostics, payload)
    if not payload:
        return Left(diagnostics.unsafe_take())
    var produced = rebind_var[Ior[S.Value, B]](_unary_once_as[X](f^, payload.unsafe_take()))
    var next_diagnostics = Optional[S.Value]()
    var next_payload = Optional[B]()
    _ior_parts(produced^).split(next_diagnostics, next_payload)
    var combined = _ior_merge[S, X](diagnostics^, next_diagnostics^)
    return _ior_from_parts(combined^, next_payload^)


def _ior_map2[S: Semigroup, Accumulate: Bool, F: BinaryContract & Movable & Deinitable,
              R: ThunkContract & Movable & Deinitable, X: Movable & Deinitable](
    var f: F, var left: Ior[S.Value, F.First], var right: R
) raises X -> Ior[S.Value, F.Out]:
    comptime assert R.Out == Ior[S.Value, F.Second], "map2: same Ior family required"
    comptime assert _ErrorCompatible[X, F.Error] and _ErrorCompatible[X, R.Error]
    var issues = Optional[S.Value]()
    var payload = Optional[F.First]()
    _ior_parts(left^).split(issues, payload)
    comptime if not Accumulate:
        if not payload:
            return Left(issues.unsafe_take())
    var produced = rebind_var[Ior[S.Value, F.Second]](_thunk_once_as[X](right^))
    var next_issues = Optional[S.Value]()
    var next_payload = Optional[F.Second]()
    _ior_parts(produced^).split(next_issues, next_payload)
    var combined_value = Optional[F.Out]()
    if payload and next_payload:
        combined_value = Optional(_binary_once_as[X](f^, payload.unsafe_take(), next_payload.unsafe_take()))
    var combined_issues = _ior_merge[S, X](issues^, next_issues^)
    return _ior_from_parts(combined_issues^, combined_value^)


struct _IorAccumulator[K: _Accumulate, S: Semigroup, Accumulate: Bool](_Accumulate):
    comptime Acc = Ior[Self.S.Value, Self.K.Acc]
    comptime Item = Ior[Self.S.Value, Self.K.Item]
    comptime Error = _CommonError[Self.S.Error, Self.K.Error]
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        comptime assert _ErrorCompatible[Self.Error, Self.K.Error]
        return Right(_start_as[Self.Error, Self.K]())
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        if acc.isa[Left[Self.S.Value]]():
            return Self.Accumulate
        if acc.isa[Right[Self.K.Acc]]():
            return Self.K.live(acc[Right[Self.K.Acc]].value)
        return Self.K.live(acc[Both[Self.S.Value, Self.K.Acc]].right)
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if not Self.live(acc):
            return acc^
        return _ior_map2[Self.S, Self.Accumulate, X=Self.Error](
            _AccumulatePair[Self.K](), acc^, _ValueThunk(item^))


struct IorFamily[S: Semigroup](Monad):
    """Sequential inclusive-or: Left stops, Both continues and retains diagnostics.

    Select this family explicitly in checked algebra or piped operations.
    Dictionary primitives assume their documented carrier/callback types;
    entry-point signature admission checks embedded origins before delegation. The
    `map` transforms a Right or Both value once, preserving its diagnostics;
    Left skips the callback. `pure` creates Right. `map2_lazy` skips its right
    thunk on Left, otherwise forces it once and calls the combiner only when
    both values exist. `flat_map` follows the same sequencing rule. Diagnostics
    combine left to right with S, after the value callback, only when both
    operands have diagnostics. `collect` uses the shared pull loop, stopping
    after the first Left and retaining all preceding warnings. Empty input is
    Right of an empty native List.

    Carriers and library callbacks are consumed, including skipped owners.
    Values and diagnostics need not be copyable. Native callback or policy
    errors propagate immediately with their exact types and clean up all owned
    values. Raising components must share one error type or raise Never.
    Operations add constant tag work and no heap storage; collect adds its
    output List and uses constant native stack space. Functor, Applicative and
    Monad laws assume associative S and pure, terminating callbacks.

    Parameters:
        S: The diagnostic Semigroup; S.Value is the left type of the Ior.
    """
    # Native signature admission retains nested diagnostic and payload origins.
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _IorDiagnostics[V] == Self.S.Value
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _IorDiagnostics[V] == Self.S.Value and Self.Element[V] == F.First and _IorDiagnostics[R.Out] == Self.S.Value and Self.Element[R.Out] == F.Second and _IorErrors[Self.S.Error, F.Error] and _IorErrors[Self.S.Error, R.Error] and _IorErrors[R.Error, F.Error]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _IorDiagnostics[F.Out] == Self.S.Value and _IorErrors[Self.S.Error, F.Error]
    comptime Element[V: Movable & Deinitable] = _IorElement[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Ior[Self.S.Value, F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Ior[Self.S.Value, A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Ior[Self.S.Value, F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[Self.S.Error, _CommonError[F.Error, R.Error]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        """Transform the right payload once, retaining all diagnostics.

        Parameters:
            V: The exact Ior carrier type.
            F: The value callback type, in any receiver mode.

        Args:
            f: The callback, consumed; Left skips it.
            value: The source Ior, consumed without copying its fields.

        Returns:
            Left unchanged, or Right/Both with the transformed value.

        Raises:
            The exact native callback error.
        """
        comptime assert V == Ior[Self.S.Value, F.Arg], "map: same Ior family required"
        return rebind_var[Self.Mapped[V, F]](_ior_map(f^, rebind_var[Ior[Self.S.Value, F.Arg]](value^)))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Introduce a value as Right, without diagnostics.

        Parameters:
            A: The value type, including its origins.

        Args:
            value: The payload, consumed.

        Returns:
            Right of the supplied value.
        """
        return Right(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine values and diagnostics according to the selected Ior policy.

        Parameters:
            V: The left Ior carrier type.
            F: The binary value callback type.
            R: The right thunk type, producing Ior with S.Value diagnostics.

        Args:
            f: The combiner, consumed and called only when both values exist.
            left: The left carrier, consumed.
            right: The consumed thunk; IorFamily skips it on Left, while
                IorValidationFamily always forces it once.

        Returns:
            The combined value when both exist, with diagnostics in order;
            otherwise Left of the diagnostics encountered by this policy.

        Raises:
            The exact native thunk, combiner or Semigroup error, immediately.
        """
        comptime assert V == Ior[Self.S.Value, F.First], "map2: same Ior family required"
        return _ior_map2[Self.S, Self.Accumulate, X=Self.CombineError[V, F, R]](
            f^, rebind_var[Ior[Self.S.Value, F.First]](left^), right^)

    comptime Accumulate = False
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Ior[Self.S.Value, K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[Self.S.Error, _CommonError[F.Error, K.Error]]

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        comptime A = _IorAccumulator[K, Self.S, Self.Accumulate]
        comptime X = Self._LoopError[V, F, K]
        comptime assert _ErrorCompatible[X, A.Error]
        return _map_accumulate[V, F, A, X](f^, source^, _start_as[X, A]())

    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.MapCompatible[V, F] and Self.CollectCompatible[V, F]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[Self.S.Error, F.Error]

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Run a dependent step and prepend earlier diagnostics to its result.

        Parameters:
            V: The source Ior type.
            F: A callback returning Ior with the same diagnostic type.

        Args:
            f: The callback, consumed and called once for Right or Both.
            value: The source, consumed; Left skips the callback.

        Returns:
            The next Ior with diagnostics in encounter order. Both followed
            by Left becomes Left containing both sets of diagnostics.

        Raises:
            The exact native callback or Semigroup error.
        """
        comptime assert V == Ior[Self.S.Value, F.Arg], "flat_map: same Ior family required"
        comptime assert F.Out == Ior[Self.S.Value, Self.Element[F.Out]], "flat_map: callback must return the same Ior diagnostic type"
        return rebind_var[Self.Bound[V, F]](_ior_bind[Self.S, F, Self.BindError[V, F]](
            f^, rebind_var[Ior[Self.S.Value, F.Arg]](value^)))


struct IorValidationFamily[S: Semigroup](Applicative):
    """Independent inclusive-or validation, accumulating diagnostics after Left.

    This alternative Applicative shares IorFamily's map, pure and combination
    kernel. It forces the right thunk once even after Left. It keeps a combined
    value only when both operands have values, and combines every present
    diagnostic in left-to-right order. A value combiner runs before S.combine,
    only when both values exist. Native raises stop immediately, including
    raises from the diagnostic policy; they never become stored diagnostics.

    List traversal and collect visit every input after stored Left values,
    discarding partial successes while retaining warnings and errors together.
    Empty input produces Right of an empty List. This policy is Applicative
    only: it has no dependent flat_map. No threads or runtime wrapper are added.
    Ownership, costs and error compatibility follow IorFamily. Applicative laws
    assume associative S and pure, terminating callbacks.

    Parameters:
        S: The diagnostic Semigroup, such as NonEmptyListSemigroup[E].
    """
    # Native signature admission retains nested diagnostic and payload origins.
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _IorDiagnostics[V] == Self.S.Value
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _IorDiagnostics[V] == Self.S.Value and Self.Element[V] == F.First and _IorDiagnostics[R.Out] == Self.S.Value and Self.Element[R.Out] == F.Second and _IorErrors[Self.S.Error, F.Error] and _IorErrors[Self.S.Error, R.Error] and _IorErrors[R.Error, F.Error]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _IorDiagnostics[F.Out] == Self.S.Value and _IorErrors[Self.S.Error, F.Error]
    comptime Element[V: Movable & Deinitable] = _IorElement[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Ior[Self.S.Value, F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Ior[Self.S.Value, A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Ior[Self.S.Value, F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[Self.S.Error, _CommonError[F.Error, R.Error]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        """Transform the right payload once, retaining all diagnostics.

        Parameters:
            V: The exact Ior carrier type.
            F: The value callback type, in any receiver mode.

        Args:
            f: The callback, consumed; Left skips it.
            value: The source Ior, consumed without copying its fields.

        Returns:
            Left unchanged, or Right/Both with the transformed value.

        Raises:
            The exact native callback error.
        """
        comptime assert V == Ior[Self.S.Value, F.Arg], "map: same Ior family required"
        return rebind_var[Self.Mapped[V, F]](_ior_map(f^, rebind_var[Ior[Self.S.Value, F.Arg]](value^)))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Introduce a value as Right, without diagnostics.

        Parameters:
            A: The value type, including its origins.

        Args:
            value: The payload, consumed.

        Returns:
            Right of the supplied value.
        """
        return Right(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine values and diagnostics according to the selected Ior policy.

        Parameters:
            V: The left Ior carrier type.
            F: The binary value callback type.
            R: The right thunk type, producing Ior with S.Value diagnostics.

        Args:
            f: The combiner, consumed and called only when both values exist.
            left: The left carrier, consumed.
            right: The consumed thunk; IorFamily skips it on Left, while
                IorValidationFamily always forces it once.

        Returns:
            The combined value when both exist, with diagnostics in order;
            otherwise Left of the diagnostics encountered by this policy.

        Raises:
            The exact native thunk, combiner or Semigroup error, immediately.
        """
        comptime assert V == Ior[Self.S.Value, F.First], "map2: same Ior family required"
        return _ior_map2[Self.S, Self.Accumulate, X=Self.CombineError[V, F, R]](
            f^, rebind_var[Ior[Self.S.Value, F.First]](left^), right^)

    comptime Accumulate = True
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Ior[Self.S.Value, K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[Self.S.Error, _CommonError[F.Error, K.Error]]

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        comptime A = _IorAccumulator[K, Self.S, Self.Accumulate]
        comptime X = Self._LoopError[V, F, K]
        comptime assert _ErrorCompatible[X, A.Error]
        return _map_accumulate[V, F, A, X](f^, source^, _start_as[X, A]())
