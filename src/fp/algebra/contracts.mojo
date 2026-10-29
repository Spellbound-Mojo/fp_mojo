"""Compile-time operation contracts; families remain the execution owners.

Input equality is separate from family admission so callers that already know
the input type can forward just the family proof. In particular, do not add
input equality to a family's MapCompatible: lifted effect projections can be
opaque until the operation is specialized. These descriptors store no values,
adapt no callbacks and introduce no additional invocation boundary.
"""
from std.builtin.rebind import downcast
from ._primitive_contracts import MapContract, BindContract, CombineContract, FilterMapContract, FilterContract
from .protocols import Functor, Monad, Traversable, Applicative
from fp.iteration._advance import _OwnedElement
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, BorrowCallable, _ErrorProbe
from fp.callables._transforms import _ValueThunk, _Pair, _Apply, _Fill, _TupleWith
from .protocols import Monoid, _AllLive, _LiveAccumulator
from ._accumulation import _FoldMappedStep, _SearchStep, _FirstPresent, _BoolLive, _PredicateStep
from ._sequencing import _EffectRetain, _IfEffect
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, _OnceUnaryAvailable, _OnceThunkAvailable
from fp._internal.errors import _CommonError, _ErrorCompatible
from fp.callables._identity import Identity
from fp.iteration._advance import _Source


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


comptime FillContract[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable] = MapContract[I, V, _Fill[I.Element[V], U]]
"""The admission, family, result and construction error of filling a carrier.

This is MapContract specialized with the ordinary replacement callback; it
stores no value and introduces no execution path. A generic wrapper forwards
InvocationCompatible, returns Out and raises Error. A fluent wrapper also
projects Family and retains its selected Pipeline error parameter.

The family's map policy admits the replacement: a single invocation moves it,
while repeated mapping requires Copyable and copies it. Deferred computations
retain their existing execution-time error and origin requirements. Error
describes construction of Out, not every later run of a deferred computation.

Parameters:
    I: The selected Functor family, preserving its evaluation and receiver policy.
    V: The complete source carrier type, including origins.
    U: The replacement type, including its origins and ownership requirements.
"""


comptime VoidContract[I: Functor, V: Movable & Deinitable] = FillContract[I, V, NoneType]
"""The admission, family, result and construction error of discarding payloads.

This specializes FillContract with NoneType, matching the ordinary void
operation. Forward InvocationCompatible, Out, Error and, for fluent wrappers,
Family. The source is consumed; its shape, stored errors and native origins
follow the family's existing mapping policy. Deferred execution remains with
that family and retains its own run requirements.

Parameters:
    I: The selected Functor family.
    V: The complete source carrier type, including origins.
"""


comptime TupleLeftContract[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable] = MapContract[I, V, _TupleWith[I.Element[V], U, True]]
"""The admission, family, result and construction error of a left attachment.

This specializes MapContract with the canonical tuple callback. Generic code
forwards InvocationCompatible, returns Out and raises Error. Fluent wrappers
also project Family and retain their selected Pipeline error parameter. The
family's map policy moves the attachment for a single invocation or requires
Copyable for repetition. All origins remain exact. Error describes construction
of Out; a deferred family's execution-time errors remain part of that family.

Parameters:
    I: The selected Functor family.
    V: The complete consumed source carrier type, including origins.
    U: The attachment type, including origins and ownership requirements.
"""


comptime TupleRightContract[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable] = MapContract[I, V, _TupleWith[I.Element[V], U, False]]
"""The admission, family, result and construction error of a right attachment.

This has the same ownership, error and forwarding contract as TupleLeftContract,
with the source element first in the resulting pair. It names the existing map
operation and introduces no additional execution or callback boundary.

Parameters:
    I: The selected Functor family.
    V: The complete consumed source carrier type, including origins.
    U: The attachment type, including origins and ownership requirements.
"""


comptime Map2Contract[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable] = CombineContract[I, V, F, _ValueThunk[W]]
"""The combination contract for two already evaluated carriers.

This is CombineContract with the existing owned-value thunk for the right
operand. It adds no execution path or copying. Generic wrappers can forward
Compatible and name Out and Error without importing that private adapter.
Component predicates remain available: the legacy free map2 entry requires
OperationCompatible, while selected pipelines also check inputs and carriers.
The family still owns branching, skipping, deferral and callback invocation.

Parameters:
    I: The selected Applicative family.
    V: The complete left carrier type, including origins.
    W: The complete already evaluated right carrier type, including origins.
    F: The library binary callback, including its receiver and native error.
"""


comptime ProductContract[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable] = Map2Contract[I, V, W, _Pair[I.Element[V], I.Element[W]]]
"""The exact contract of pairing two already evaluated carriers.

This specializes Map2Contract with the canonical pair callback. Generic code
can forward Compatible and name Out and Error without private adapter types.
OperationCompatible preserves the legacy free and piped admission, while
FamilyCompatible additionally supplies selected-pipeline carrier checks.
The family retains its ordering, copying, failure and deferral semantics.

Parameters:
    I: The selected Applicative family.
    V: The complete left carrier type, including origins.
    W: The complete already evaluated right carrier type, including origins.
"""


comptime _Function[I: Applicative, V: Movable & Deinitable] = downcast[I.Element[V], UnaryContract & Movable & Deinitable]


struct ApContract[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable]:
    """The exact contract of applying stored library callbacks to stored values.

    The existing pairwise combination and callable dispatcher own execution.
    This descriptor only names admission and result metadata for generic code.

    Parameters:
        I: The selected Applicative family.
        V: The complete carrier of library callbacks, including origins.
        W: The complete carrier of argument values, including origins.
    """
    comptime Function = _Function[Self.I, Self.V]
    """The callback type projected from the left carrier."""
    comptime _Applied = Map2Contract[Self.I, Self.V, Self.W, _Apply[Self.Function]]
    comptime CallableCompatible = conforms_to(Self.I.Element[Self.V], UnaryContract & Movable & Deinitable)
    """The left payload declares the library unary callable contract."""
    comptime InputCompatible = Self.CallableCompatible and Self.I.Element[Self.W] == Self.Function.Arg
    """Callable membership and exact argument equality, including origins."""
    comptime OperationCompatible = Self._Applied.OperationCompatible
    """Legacy free-function admission through the family's combination policy."""
    comptime FamilyCompatible = Self._Applied.FamilyCompatible
    """Operation admission and membership of both carriers."""
    comptime ReceiverCompatible = Self.CallableCompatible and _OnceUnaryAvailable[Self.Function]
    """The callback has a consuming, mutable or shared invocation mode."""
    comptime ShapeCompatible = Self.InputCompatible and Self.FamilyCompatible
    """Legacy selected admission; receiver dispatch remains checked at invocation."""
    comptime Compatible = Self.ShapeCompatible and Self.ReceiverCompatible
    """Shape admission plus availability of the stored callback receiver."""
    comptime Family = Self.I
    """The selected family of the result."""
    comptime Out = Self._Applied.Out
    """The exact carrier of callback results."""
    comptime Error = Self._Applied.Error
    """The exact native construction error; deferred errors stay deferred."""


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
    A staged wrapper can forward InvocationCompatible to include the required
    repeatable receiver; existing Compatible proofs retain their meaning.

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
    comptime ReceiverCompatible = RepeatableBinary[Self.F]
    """The step has a shared or mutable receiver and remains usable after a call."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing fold admission plus the staged entry's repeatable-step requirement."""
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
    comptime _Bind = BindContract[Self.I, Self.V, Self._Branch]
    comptime _ErrorBind = BindContract[Self.I, Self.V, Self._Probe]
    comptime InputCompatible = Self.I.Element[Self.V] == Bool
    """The condition carries exactly Bool."""
    comptime OutputCompatible = Self.I.Element[Self.L.Out] == Self.I.Element[Self.R.Out]
    """Branch payloads match exactly, including their origins."""
    comptime CarrierCompatible = Self.I.CarrierCompatible[Self.V] and Self.I.CarrierCompatible[Self.L.Out] and Self.I.CarrierCompatible[Self.R.Out]
    """The condition and both branches belong to the selected family."""
    comptime NativeErrorsCompatible = _ErrorCompatible[Self._Raised, Self.L.Error] and _ErrorCompatible[Self._Raised, Self.R.Error]
    """Branch native errors share one exact raised type without conversion."""
    comptime FamilyCompatible = Self._Bind.FamilyCompatible
    """The family's admission of the branch continuation and its receiver."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self._Bind.Out
    """The exact carrier produced by conditional binding."""
    comptime Error = Self._ErrorBind.Error
    """The native construction error; deferred execution errors stay in Out."""
    comptime ShapeCompatible = Self.InputCompatible and Self.OutputCompatible and Self.CarrierCompatible
    """The legacy free entry's shape admission; family execution checks its own requirements."""
    comptime Compatible = Self.ShapeCompatible and Self.NativeErrorsCompatible and Self.FamilyCompatible
    """Legacy selected admission, with branch receiver dispatch checked at invocation."""
    comptime ReceiverCompatible = _OnceThunkAvailable[Self.L] and _OnceThunkAvailable[Self.R]
    """Both branch factories have a consuming, mutable or shared receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Selected admission plus receiver availability for both branch factories."""
