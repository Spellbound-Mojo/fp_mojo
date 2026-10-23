"""Signature constraints preserving nominal carriers and embedded origins."""
from fp.algebra.protocols import Applicative
from fp.data._result import _ResultType

# The same Result check is used by traversal and conditional admission. Keeping
# it in a signature matters: a body-level rebind/identity assertion can accept
# different embedded origins on Mojo 1.1. Deferred carriers need not equal Pure.
comptime _ResultCarrierCompatible[I: Applicative, V: Movable & Deinitable] = (
    V == I.Pure[I.Element[V]] if conforms_to(I.Pure[NoneType], _ResultType) else True
)
