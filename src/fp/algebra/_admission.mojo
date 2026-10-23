"""Signature constraints preserving nominal carriers and embedded origins."""
from fp.algebra.protocols import Functor, Applicative, Monad
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp.data._result import _ResultType
from fp.functions.composition import Identity

# Public family predicates let generic forwarders state their preconditions.
comptime _MapCompatible[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.MapCompatible[V, F]
comptime _BindCompatible[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.BindCompatible[V, F]
comptime _CombineCompatible[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = I.CombineCompatible[V, F, R]
comptime _CollectCompatible[I: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = I.CollectCompatible[V, F]


# Fixed-carrier and family checks are shared by traversal and conditional admission. Keeping
# it in a signature matters: a body-level rebind/identity assertion can accept
# different embedded origins on Mojo 1.1. Deferred carriers need not equal Pure.
comptime _CarrierCompatible[I: Applicative, V: Movable & Deinitable] = (
    _MapCompatible[I, V, Identity[I.Element[V]]] and
    (V == I.Pure[I.Element[V]] if conforms_to(I.Pure[NoneType], _ResultType) else True)
)
