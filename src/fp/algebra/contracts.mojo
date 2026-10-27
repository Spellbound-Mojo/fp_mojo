"""Compile-time operation contracts; families remain the execution owners.

Input equality is separate from family admission so callers that already know
the input type can forward just the family proof. In particular, do not add
input equality to a family's MapCompatible: lifted effect projections can be
opaque until the operation is specialized. These descriptors store no values,
adapt no callbacks and introduce no additional invocation boundary.
"""
from std.builtin.rebind import downcast
from .protocols import _MappedFamily, Functor, Monad, Traversable, Applicative, Filterable, FunctorFilter
from fp.iteration._advance import _OwnedElement
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, BorrowCallable, _ErrorProbe
from fp.callables._predicates import _FilterPredicate
from .protocols import Monoid, _AllLive, _LiveAccumulator
from ._accumulation import _FoldMappedStep, _SearchStep, _FirstPresent, _BoolLive, _PredicateStep
from ._sequencing import _EffectRetain, _IfEffect
from fp.callables.invoke import RepeatableUnary
from fp._internal.errors import _CommonError, _ErrorCompatible
from fp.callables._identity import Identity
from fp.iteration._advance import _Source


struct MapContract[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """The admission, result and error of mapping a library callable.

    A generic wrapper can return `MapContract[I, V, F].Out`, raise its `Error`
    and forward `where MapContract[I, V, F].Compatible`. Native callbacks first
    use their existing admission adapters; the contract does not infer native
    signatures. Family primitives retain their receiver and evaluation rules.

    Parameters:
        I: The selected Functor family.
        V: The complete source carrier type, including origins.
        F: The library callback type, including its receiver and error.
    """
    comptime InputCompatible = Self.I.Element[Self.V] == Self.F.Arg
    """Exact payload equality, including embedded origins."""
    comptime FamilyCompatible = Self.I.MapCompatible[Self.V, Self.F]
    """The family's admission without forcing input equality again."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete checked map admission."""
    comptime Family = _MappedFamily[Self.I, Self.F.Out]
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Mapped[Self.V, Self.F]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.MapError[Self.V, Self.F]
    """The exact native error raised when constructing the mapped carrier."""


struct FilterMapContract[I: FunctorFilter, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """Result metadata for filter_map and its fluent continuation.

    The family primitive owns Optional-result admission and invocation. This
    descriptor exposes the existing selected signature's input constraint as
    Compatible; it does not add map's carrier proof to
    filtering. The legacy free function keeps its existing admission policy.

    Parameters:
        I: The source family supporting filter_map.
        V: The complete source carrier type, including origins.
        F: The library callback type, with its Optional result and native error.
    """
    comptime InputCompatible = Self.I.Element[Self.V] == Self.F.Arg
    """Exact input payload equality, including origins."""
    comptime Compatible = Self.InputCompatible
    """The selected filter_map signature's admission; family primitives check representation and receiver requirements."""
    comptime Family = _MappedFamily[Self.I.MapFilteredFamily, _OwnedElement[Self.F.Out]]
    """The output shape family, rebound to the present transformed payload."""
    comptime Out = Self.I.MapFiltered[Self.V, Self.F]
    """The carrier of present transformed payloads."""
    comptime Error = Self.I.MapFilterError[Self.V, Self.F]
    """The family's exact construction error."""


struct BindContract[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """The admission, result and error of flat_map with a library callable.

    Forward `Compatible` in generic wrappers and use `Out` and `Error` for
    their return and raised types. The family decides which carrier
    representations it admits, including deferred computations.

    Parameters:
        I: The selected Monad family.
        V: The complete source carrier type, including origins.
        F: The library callback producing the next carrier.
    """
    comptime InputCompatible = Self.I.Element[Self.V] == Self.F.Arg
    """Exact payload equality, including embedded origins."""
    comptime FamilyCompatible = Self.I.BindCompatible[Self.V, Self.F]
    """The family's binding admission."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete checked flat_map admission."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Bound[Self.V, Self.F]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.BindError[Self.V, Self.F]
    """The exact native error raised when constructing the bound carrier."""


struct TraverseContract[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """The joint source and target contract of traversal with a library callable.

    `Compatible` combines input equality, source traversal admission, the target
    operations selected by that source and callback-output membership. Generic wrappers
    forward that one predicate and use `Out` and `Error`. Source traversal is
    intentionally distinct from source mapping: a family can traverse more
    source representations than it maps.

    Parameters:
        S: The source Traversable family.
        G: The target Applicative family.
        V: The complete consumed source type, including origins.
        F: The library callback producing target-family carriers.
    """
    comptime InputCompatible = Self.S.Element[Self.V] == Self.F.Arg
    """Exact source-element equality, including embedded origins."""
    comptime SourceCompatible = Self.S.TraverseCompatible[Self.V, Self.F]
    """The source family's traversal admission, independent of map."""
    comptime TargetCompatible = Self.S.TargetCompatible[Self.G, Self.V, Self.F]
    """Admission for the target operations selected by this source traversal."""
    comptime CollectCompatible = Self.G.CollectCompatible[Self.V, Self.F]
    """Direct collection admission; a single-value source may not collect."""
    comptime CarrierCompatible = Self.G.CarrierCompatible[Self.F.Out]
    """The callback's output belongs to the target family."""
    comptime FamilyCompatible = Self.SourceCompatible and Self.TargetCompatible and Self.CarrierCompatible
    """Source and target admission without repeating input equality."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete checked traversal admission."""
    comptime Family = Self.G
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.S.Traversed[Self.G, Self.V, Self.F]
    """The exact traversal result, retaining source shape and target effect."""
    comptime Error = Self.S.TraverseError[Self.G, Self.V, Self.F]
    """The exact native error raised when constructing the traversal."""


struct FilterContract[I: Filterable, V: Movable & Deinitable, P: BorrowCallable, inverted: Bool = False]:
    """The admission, output and exact error of borrowing predicate selection.

    Forward `Compatible` in a generic wrapper of `filter` or `filter_not`.
    Inversion changes the predicate supplied to the family, so its associated
    output and error must be projected using that adapted predicate too.
    Filtering does not require the family to implement Functor.

    Parameters:
        I: The selected Filterable family.
        V: The complete consumed carrier type, including origins.
        P: The repeatable borrowing predicate type.
        inverted: Select filter_not semantics; False selects filter.
    """
    comptime InputCompatible = Self.I.Element[Self.V] == Self.P.Payload
    """Exact predicate payload equality, including embedded origins."""
    comptime PredicateCompatible = Self.P.Result == Bool
    """The predicate returns the native Bool type."""
    comptime Compatible = Self.InputCompatible and Self.PredicateCompatible
    """The complete checked filtering admission."""
    comptime Family = downcast[Self.I.FilteredFamily, Functor]
    """The output Functor; project only when FilteredFamily conforms to Functor."""
    comptime Predicate = _FilterPredicate[Self.P, Self.inverted]
    """The predicate supplied to the family after optional inversion."""
    comptime Out = Self.I.Filtered[Self.V, Self.Predicate]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.FilterError[Self.V, Self.Predicate]
    """The exact construction error, including predicate-dependent family errors."""


struct CombineContract[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]:
    """The joint contract of a left carrier, binary callback and lazy right carrier.

    `Compatible` combines exact operand equality, carrier membership and the
    family's operation predicate. Component predicates remain available for
    legacy admission, which may intentionally require only OperationCompatible.
    This descriptor never evaluates the right thunk or chooses eager versus
    deferred execution. The family's Combined and CombineError own those types.

    Parameters:
        I: The selected Applicative family.
        V: The complete left carrier type, including origins.
        F: The binary library callback.
        R: The consuming or repeatable thunk producing the right carrier.
    """
    comptime InputCompatible = Self.I.Element[Self.V] == Self.F.First and Self.I.Element[Self.R.Out] == Self.F.Second
    """Exact left and right payload equality, including embedded origins."""
    comptime LeftCompatible = Self.I.CarrierCompatible[Self.V]
    """The left value belongs to the selected family."""
    comptime RightCompatible = Self.I.CarrierCompatible[Self.R.Out]
    """The right thunk produces a carrier of the selected family."""
    comptime OperationCompatible = Self.I.CombineCompatible[Self.V, Self.F, Self.R]
    """The family's own combination predicate, without additional constraints."""
    comptime FamilyCompatible = Self.OperationCompatible and Self.LeftCompatible and Self.RightCompatible
    """Family admission without repeating callback operand equality."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete checked lazy combination admission."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Combined[Self.V, Self.F, Self.R]
    """The exact carrier produced by the family, including deferred types."""
    comptime Error = Self.I.CombineError[Self.V, Self.F, Self.R]
    """The family's exact construction error, including callback and thunk effects."""


struct _EffectFold[G: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]:
    comptime Prepare = Identity[Self.F.Second]
    comptime Compatible = Self.G._FoldCompatible[Self.V, Self.Prepare, Self.F, Self.K]
    comptime Out = Self.G._Folded[Self.V, Self.Prepare, Self.F, Self.K]
    comptime Error = Self.G._FoldError[Self.V, Self.Prepare, Self.F, Self.K]



struct FoldContract[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable]:
    """Admission, output and error for an effectful fold with a library callable.

    A generic wrapper forwards `Compatible`, returns `Out` and raises `Error`.
    The target family owns dependent sequencing; custom families retain their
    existing fold admission unless they declare additional requirements.

    Parameters:
        I: The target Monad family.
        V: The consumed source type, including its native origins.
        F: The binary accumulator step, including receiver and native error.
    """
    comptime _Plan = _EffectFold[Self.I, Self.V, Self.F, _AllLive[Self.F.First]]
    comptime InputCompatible = _Source[Self.V].Element == Self.F.Second
    """Exact source-element and step-input equality, including origins."""
    comptime OutputCompatible = Self.I.CarrierCompatible[Self.F.Out] and Self.I.Element[Self.F.Out] == Self.F.First
    """The step returns this family's carrier of the unchanged accumulator type."""
    comptime FamilyCompatible = Self._Plan.Compatible
    """Requirements declared by the target family's dependent fold."""
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.FamilyCompatible
    """The complete checked fold admission with its inferred construction error."""
    comptime Out = Self._Plan.Out
    """The exact family result, including deferred computations."""
    comptime Error = Self._Plan.Error
    """The exact native error raised while constructing the fold result."""


struct FoldMapContract[I: Monad, M: Monoid, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """Admission, result and construction error of an effectful mapped fold.

    Generic wrappers forward `Compatible`, return `Out` and raise `Error`.
    The family owns sequencing; the monoid supplies the initial value and
    ordered combination. Its initial value is constructed before a deferred
    family is returned, while callback execution follows the family's timing.

    Parameters:
        I: The target Monad family.
        M: The Monoid combining produced payloads in source order.
        V: The consumed source type, including native origins.
        F: The repeatable unary producer, including its receiver and error.
    """
    comptime _Step = _FoldMappedStep[Self.I, Self.M, Self.F]
    comptime _Plan = _EffectFold[Self.I, Self.V, Self._Step, _AllLive[Self.M.Value]]
    comptime InputCompatible = _Source[Self.V].Element == Self.F.Arg
    """The producer accepts the exact source element, including origins."""
    comptime OutputCompatible = Self.I.CarrierCompatible[Self.F.Out] and Self.I.Element[Self.F.Out] == Self.M.Value
    """The producer returns the selected family's carrier of monoid values."""
    comptime ReceiverCompatible = RepeatableUnary[Self.F]
    """The producer can be called for each visited source element."""
    comptime MapCompatible = Self.I.MapCompatible[Self.F.Out, Self._Step.Combine]
    """Family admission of combination, including branch copying requirements."""
    comptime ErrorsCompatible = _ErrorCompatible[_CommonError[Self.F.Error, Self.M.Error], Self.M.Error]
    """Producer and monoid errors share an exact native error type."""
    comptime FamilyCompatible = Self._Plan.Compatible
    """Requirements declared by the family's dependent fold."""
    comptime InitializerErrorCompatible = _ErrorCompatible[Self.Error, Self.M.Error]
    """Explicit native evidence that the construction error includes initialization."""
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.ReceiverCompatible and Self.MapCompatible and Self.ErrorsCompatible and Self.FamilyCompatible and Self.InitializerErrorCompatible
    """Complete mapped-fold admission with the inferred construction error."""
    comptime Out = Self._Plan.Out
    """The exact folded carrier, including deferred computation types."""
    comptime Error = _CommonError[Self.M.Error, Self._Plan.Error]
    """The native construction error, including eager monoid initialization."""


struct FindMapContract[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """Admission, result and construction error of an effectful first match.

    Generic wrappers forward `Compatible`, return `Out` and raise `Error`.
    The producer returns an effect of Optional; each live branch visits source
    elements until its first present value. Families retain their own stopping,
    branching, ownership and deferred execution rules.

    Parameters:
        I: The target Monad family.
        V: The consumed source type, including native origins.
        F: The repeatable unary producer, including its receiver and error.
    """
    comptime _Selected = _OwnedElement[Self.I.Element[Self.F.Out]]
    comptime _Step = _SearchStep[Self._Selected, Self.F]
    comptime _Plan = _EffectFold[Self.I, Self.V, Self._Step, _FirstPresent[Self._Selected]]
    comptime InputCompatible = _Source[Self.V].Element == Self.F.Arg
    """The producer accepts the exact source element, including origins."""
    comptime OutputCompatible = Self.I.CarrierCompatible[Self.F.Out] and Self.I.Element[Self.F.Out] == Optional[Self._Selected]
    """The producer returns this family's carrier of an Optional payload."""
    comptime ReceiverCompatible = RepeatableUnary[Self.F]
    """The producer can be called for each visited source element."""
    comptime FamilyCompatible = Self._Plan.Compatible
    """Requirements declared by the family's dependent fold."""
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.ReceiverCompatible and Self.FamilyCompatible
    """Complete first-match admission with the inferred construction error."""
    comptime Out = Self._Plan.Out
    """The exact folded carrier, including deferred computation types."""
    comptime Error = Self._Plan.Error
    """The native construction error; deferred execution retains its own errors."""


struct FindContract[I: Monad, V: Movable & Deinitable, C: BorrowCallable]:
    """Admission, result and construction error of an effectful borrowing search.

    Generic wrappers forward `Compatible`, return `Out` and raise `Error`.
    The predicate borrows each visited element and produces an effectful Bool.
    Each branch retains its first accepted original element without copying it
    unless the selected family branches. Families own execution and stopping.

    Parameters:
        I: The target Monad family.
        V: The consumed source type, including native origins.
        C: The repeatable borrowing predicate, including receiver and error.
    """
    comptime _Element = downcast[Self.C.Payload, Movable & Deinitable]
    comptime _Retained = _EffectRetain[Self._Element, Self.I, Self.C, True]
    comptime _Step = _SearchStep[Self._Element, Self._Retained]
    comptime _Plan = _EffectFold[Self.I, Self.V, Self._Step, _FirstPresent[Self._Element]]
    comptime InputCompatible = _Source[Self.V].Element == Self._Element
    """The predicate borrows the exact source element, including origins."""
    comptime OutputCompatible = Self.I.CarrierCompatible[Self.C.Result] and Self.I.Element[Self.C.Result] == Bool
    """The predicate returns this family's carrier of a Bool."""
    comptime ReceiverCompatible = RepeatableUnary[Self._Retained]
    """The retention callback can visit each required source element."""
    comptime FamilyCompatible = Self._Plan.Compatible
    """Requirements declared by the family's dependent fold."""
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.ReceiverCompatible and Self.FamilyCompatible
    """Complete borrowing-search admission with the inferred construction error."""
    comptime Out = Self._Plan.Out
    """The exact folded carrier of original elements, including deferred computations."""
    comptime Error = Self._Plan.Error
    """The native construction error; deferred execution retains its own errors."""


struct _PredicateFoldContract[I: Monad, V: Movable & Deinitable, C: BorrowCallable, all_values: Bool]:
    """One admission and metadata owner for the two Boolean stopping policies."""
    comptime _Step = _PredicateStep[Self.C]
    comptime _Plan = _EffectFold[Self.I, Self.V, Self._Step, _BoolLive[Self.all_values]]
    comptime InputCompatible = _Source[Self.V].Element == downcast[Self.C.Payload, Movable & Deinitable]
    comptime OutputCompatible = Self.I.CarrierCompatible[Self.C.Result] and Self.I.Element[Self.C.Result] == Bool
    comptime FamilyCompatible = Self._Plan.Compatible
    comptime Compatible = Self.InputCompatible and Self.OutputCompatible and Self.FamilyCompatible
    comptime Out = Self._Plan.Out
    comptime Error = Self._Plan.Error


comptime AnyContract[I: Monad, V: Movable & Deinitable, C: BorrowCallable] = _PredicateFoldContract[I, V, C, False]
"""Admission, result and construction error of any_effect.

Forward `Compatible`, return `Out` and raise `Error` in generic wrappers.
`InputCompatible` checks exact predicate input, `OutputCompatible` checks its
family carrier of Bool, and `FamilyCompatible` checks dependent-fold admission.
Each branch stops at its first True; empty input lifts False. The family retains
branching, ownership and deferred execution, including native errors and origins.

Parameters:
    I: The target Monad family.
    V: The consumed source type, including native origins.
    C: The repeatable borrowing predicate, including receiver and error.
"""


comptime AllContract[I: Monad, V: Movable & Deinitable, C: BorrowCallable] = _PredicateFoldContract[I, V, C, True]
"""Admission, result and construction error of all_effect.

Forward `Compatible`, return `Out` and raise `Error` in generic wrappers.
Component predicates have the same meaning as AnyContract. Each branch stops
at its first False; empty input lifts True. Both operations share one contract
implementation and preserve the family's execution and ownership rules.

Parameters:
    I: The target Monad family.
    V: The consumed source type, including native origins.
    C: The repeatable borrowing predicate, including receiver and error.
"""


struct IfContract[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]:
    """The admission, result and construction error of an effectful conditional.

    Generic wrappers forward Compatible and name Out and Error. The family
    still owns branch ordering, repeated invocation and deferred execution.
    Native callback boundaries retain their explicit signature error evidence.

    Parameters:
        I: The selected Monad family.
        V: The complete consumed condition carrier, including origins.
        L: The owned true-branch factory, including its receiver and native error.
        R: The owned false-branch factory, including its receiver and native error.
    """
    comptime _Branch = _IfEffect[Self.I, Self.L, Self.R]
    comptime _Raised = _CommonError[Self.L.Error, Self.R.Error]
    comptime _Probe = _ErrorProbe[Bool, Self.I._Joined[Self.L.Out, Self.R.Out], Self._Raised]
    comptime InputCompatible = Self.I.Element[Self.V] == Bool
    """The condition carries exactly Bool."""
    comptime OutputCompatible = Self.I.Element[Self.L.Out] == Self.I.Element[Self.R.Out]
    """Branch payloads match exactly, including their origins."""
    comptime CarrierCompatible = Self.I.CarrierCompatible[Self.V] and Self.I.CarrierCompatible[Self.L.Out] and Self.I.CarrierCompatible[Self.R.Out]
    """The condition and both branches belong to the selected family."""
    comptime NativeErrorsCompatible = _ErrorCompatible[Self._Raised, Self.L.Error] and _ErrorCompatible[Self._Raised, Self.R.Error]
    """Branch native errors share one exact raised type without conversion."""
    comptime FamilyCompatible = Self.I.BindCompatible[Self.V, Self._Branch]
    """The family's admission of the branch continuation and its receiver."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Bound[Self.V, Self._Branch]
    """The exact carrier produced by conditional binding."""
    comptime Error = Self.I.BindError[Self.V, Self._Probe]
    """The native construction error; deferred execution errors stay in Out."""
    comptime ShapeCompatible = Self.InputCompatible and Self.OutputCompatible and Self.CarrierCompatible
    """The legacy free entry's shape admission; family execution checks its own requirements."""
    comptime Compatible = Self.ShapeCompatible and Self.NativeErrorsCompatible and Self.FamilyCompatible
    """The complete selected conditional admission, available to generic wrappers."""
