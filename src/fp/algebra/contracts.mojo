"""Compile-time operation contracts; families remain the execution owners.

Input equality is separate from family admission so callers that already know
the input type can forward just the family proof. In particular, do not add
input equality to a family's MapCompatible: lifted effect projections can be
opaque until the operation is specialized. These descriptors store no values,
adapt no callbacks and introduce no additional invocation boundary.
"""
from .protocols import Functor, Monad, Traversable, Applicative
from fp.callables.protocols import UnaryContract


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
    """The complete checked flat_map admission."""
    comptime Out = Self.I.Bound[Self.V, Self.F]
    """The exact carrier produced by the family."""
    comptime Error = Self.I.BindError[Self.V, Self.F]
    """The exact native error raised when constructing the bound carrier."""


struct TraverseContract[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]:
    """The joint source and target contract of traversal with a library callable.

    `Compatible` combines input equality, source traversal admission, target
    collection admission and callback-output membership. Generic wrappers
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
    comptime CollectCompatible = Self.G.CollectCompatible[Self.V, Self.F]
    """The target family's collection admission."""
    comptime CarrierCompatible = Self.G.CarrierCompatible[Self.F.Out]
    """The callback's output belongs to the target family."""
    comptime FamilyCompatible = Self.SourceCompatible and Self.CollectCompatible and Self.CarrierCompatible
    """Source and target admission without repeating input equality."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete checked traversal admission."""
    comptime Out = Self.S.Traversed[Self.G, Self.V, Self.F]
    """The exact traversal result, retaining source shape and target effect."""
    comptime Error = Self.S.TraverseError[Self.G, Self.V, Self.F]
    """The exact native error raised when constructing the traversal."""
