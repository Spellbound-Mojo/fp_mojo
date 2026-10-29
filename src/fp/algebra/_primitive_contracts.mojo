"""Primitive operation metadata, below derived algebra continuations.

Public contracts and package initializers re-export these exact declarations.
This module depends on family protocols and lower callable/iterator metadata.
"""
from std.builtin.rebind import downcast
from fp.callables._predicates import _FilterPredicate
from fp.iteration._advance import _OwnedElement
from .protocols import _MappedFamily, Functor, Monad, Applicative, ApplicativeError, ErrorRecovery, Filterable, FunctorFilter
from fp.callables.protocols import BorrowCallContract, UnaryContract, BinaryContract, ThunkContract
from fp.callables.invoke import RepeatableBorrow, _OnceUnaryAvailable, _OnceBinaryAvailable, _OnceThunkAvailable


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
    """Existing map admission, preserving the expanded input and family proof."""
    comptime ReceiverCompatible = _OnceUnaryAvailable[Self.F]
    """The callback has a consuming, mutable or shared receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing admission plus callback receiver availability for new wrappers."""
    comptime Family = _MappedFamily[Self.I, Self.F.Out]
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Mapped[Self.V, Self.F]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.MapError[Self.V, Self.F]
    """The exact native error raised when constructing the mapped carrier."""


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
    """Existing bind admission, preserving the expanded input and family proof."""
    comptime ReceiverCompatible = _OnceUnaryAvailable[Self.F]
    """The callback has a consuming, mutable or shared receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing admission plus callback receiver availability for new wrappers."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Bound[Self.V, Self.F]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.BindError[Self.V, Self.F]
    """The exact native error raised when constructing the bound carrier."""


struct _HandleContract[I: ErrorRecovery, V: Movable & Deinitable,
                       H: UnaryContract & Movable & Deinitable]:
    """Primitive family recovery metadata, without derived entry constraints.

    Derived operations retain their own payload, receiver, carrier and native
    error guards. This descriptor projects the family's exact operation and
    introduces no value lifting, handler adaptation or execution boundary.
    """
    comptime FamilyCompatible = Self.I._Handles[Self.V, Self.H]
    comptime Out = Self.I.Handled[Self.V, Self.H]
    comptime Error = Self.I.HandleError[Self.V, Self.H]


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
    """Existing combination admission, preserving expanded input and family proofs."""
    comptime ReceiverCompatible = _OnceBinaryAvailable[Self.F] and _OnceThunkAvailable[Self.R]
    """The binary callback and right factory each have an invocable receiver."""
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible
    """Existing admission plus callback receiver availability for new wrappers."""
    comptime Family = Self.I
    """The family selected for fluent continuation over Out."""
    comptime Out = Self.I.Combined[Self.V, Self.F, Self.R]
    """The exact carrier produced by the family, including deferred types."""
    comptime Error = Self.I.CombineError[Self.V, Self.F, Self.R]
    """The family's exact construction error, including callback and thunk effects."""


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


struct FilterContract[I: Filterable, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, inverted: Bool = False]:
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
    comptime ReceiverCompatible = RepeatableBorrow[Self.P]
    """A shared or mutable receiver permits repeated calls."""
    comptime PredicateCompatible = Self.P.Result == Bool
    """The predicate returns the native Bool type."""
    comptime Compatible = Self.InputCompatible and Self.PredicateCompatible and Self.ReceiverCompatible
    """The complete checked filtering admission."""
    comptime Family = downcast[Self.I.FilteredFamily, Functor]
    """The output Functor; project only when FilteredFamily conforms to Functor."""
    comptime Predicate = _FilterPredicate[Self.P, Self.inverted]
    """The predicate supplied to the family after optional inversion."""
    comptime Out = Self.I.Filtered[Self.V, Self.Predicate]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.FilterError[Self.V, Self.Predicate]
    """The exact construction error, including predicate-dependent family errors."""
