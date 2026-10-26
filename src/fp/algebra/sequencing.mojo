"""Compile-time sequencing metadata; family bind remains the execution owner."""
from .protocols import Monad
from ._sequencing import _EffectRetain
from fp.callables.protocols import BorrowCallContract, ThunkContract
from fp.callables._transforms import _BorrowedUnary, _IgnoreInput


struct _SequencingContract[I: Monad, V: Movable & Deinitable,
                          C: BorrowCallContract & Movable & Deinitable,
                          retained: Bool, paired: Bool]:
    """One metadata owner for borrowed and input-independent continuations."""
    comptime Continuation = _EffectRetain[Self.I.Element[Self.V], Self.I, Self.C, False, Self.paired] if Self.retained else _BorrowedUnary[Self.I.Element[Self.V], Self.C]
    comptime InputCompatible = Self.C.Payload == Self.I.Element[Self.V]
    comptime CarrierCompatible = Self.I.CarrierCompatible[Self.C.Result]
    comptime BindCompatible = Self.I.BindCompatible[Self.V, Self.Continuation]
    comptime FamilyCompatible = Self.CarrierCompatible and Self.BindCompatible
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    comptime Family = Self.I
    comptime Out = Self.I.Bound[Self.V, Self.Continuation]
    comptime Error = Self.I.BindError[Self.V, Self.Continuation]


comptime FlatTapContract[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = _SequencingContract[I, V, C, True, False]
"""The selected flat_tap admission, output family, carrier and construction error.

Forward `Compatible` in generic selected-pipeline wrappers and project `Family`,
`Out` and `Error` for their return and raised types. `InputCompatible` checks
the borrowed payload including origins, `CarrierCompatible` checks the effect
produced by C, and `BindCompatible` is the family's continuation admission.
`FamilyCompatible` combines the latter two without repeating input equality.
Legacy Piped keeps its input-and-carrier entry checks; this descriptor does not
strengthen an existing overload. Families retain receiver and copy checks.

Parameters:
    I: The selected Monad family, including branching and deferred behavior.
    V: The complete consumed source carrier, including origins.
    C: The borrowing callback producing an effect in I.
"""


comptime FlatPairWithContract[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable] = _SequencingContract[I, V, C, True, True]
"""The selected flat_pair_with contract, retaining original/projected pairs.

Project `Family`, `Out` and `Error` and forward `Compatible` in generic selected
wrappers. Component predicates have the same meaning as FlatTapContract.
Only retained originals need copying when the selected effect branches;
projected values are moved. Family primitives still own receiver admission.

Parameters:
    I: The selected Monad family.
    V: The complete consumed source carrier, including origins.
    C: The borrowing callback producing the paired effect in I.
"""


comptime BeforeContract[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable] = _SequencingContract[I, V, _IgnoreInput[I.Element[V], F], True, False]
"""The selected before contract, retaining originals after a factory succeeds.

Project `Family`, `Out` and `Error` and forward `Compatible` in generic selected
wrappers. `InputCompatible` is satisfied by the existing ignored-input adapter;
`CarrierCompatible` checks F.Out and `BindCompatible` checks family admission.
Construction and execution keep the selected family's timing and exact errors.

Parameters:
    I: The selected Monad family.
    V: The complete consumed source carrier, including origins.
    F: The consuming or repeatable factory producing an effect in I.
"""


comptime FollowedByContract[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable] = _SequencingContract[I, V, _IgnoreInput[I.Element[V], F], False, False]
"""The selected followed_by contract, returning the factory's produced payloads.

Project `Family`, `Out` and `Error` and forward `Compatible` in generic selected
wrappers. Component predicates have the same meaning as BeforeContract.
No original payload is copied for retention. The family owns branching,
callback repeatability, deferred execution and native construction errors.

Parameters:
    I: The selected Monad family.
    V: The complete consumed source carrier, including origins.
    F: The consuming or repeatable factory producing an effect in I.
"""
