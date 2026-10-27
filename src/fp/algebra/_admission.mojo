"""Signature constraints preserving nominal carriers and embedded origins."""
from fp.algebra.protocols import Functor, Applicative, Monad, Traversable
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from .contracts import MapContract, BindContract, CombineContract

# Public family predicates let generic forwarders state their preconditions.
comptime _MapCompatible[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = MapContract[I, V, F].FamilyCompatible
comptime _BindCompatible[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = BindContract[I, V, F].FamilyCompatible
comptime _CombineCompatible[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = CombineContract[I, V, F, R].OperationCompatible
comptime _CollectCompatible[I: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.CollectCompatible[V, F]


# Fixed-carrier and family checks are shared by traversal and conditional admission. Keeping
# it in a signature matters: a body-level rebind/identity assertion can accept
# different embedded origins on Mojo 1.1. Deferred carriers need not equal Pure.
comptime _CarrierCompatible[I: Applicative, V: Movable & Deinitable] = I.CarrierCompatible[V]
comptime _TraverseCompatible[I: Traversable, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.TraverseCompatible[V, F]


# Shared shape rules for families with multiple concrete representations.
# Each family owns CarrierCompatible; these helpers never infer a family from
# a native value or require a deferred computation to have its Pure type.
# Bind shape must not inherit prerequisites of an unrelated map operation.
# Checked operations own exact callback input equality. Repeating that equality
# inside a family predicate makes lifted Listen projections reduce too early.
comptime _CarrierBind[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.CarrierCompatible[V] and I.CarrierCompatible[F.Out]
comptime _CarrierCombine[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = I.CarrierCompatible[V] and I.CarrierCompatible[G.Out] and I.Element[V] == F.First and I.Element[G.Out] == F.Second
