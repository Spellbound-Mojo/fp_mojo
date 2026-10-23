"""Sequencing continuations shared by bind, traversal and lazy iteration."""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import Unary, OnceUnary, MutableUnary, BorrowCallContract, BorrowCallable, Binary
from fp.callables.invoke import invoke_borrowed
from fp.callables._receiver import _borrow_once_as, _borrow_repeated_as, _RepeatableBorrow, _binary_once_as
from fp.callables._transforms import _Retained
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import Functor
from fp.callables._retention import _Retain


@fieldwise_init
struct _MapRetained[T: Movable & Deinitable, G: Functor, V: Movable & Deinitable,
                    selected: Bool, paired: Bool](Binary, Defaultable):
    """Finish ordinary retention by mapping the original into each success."""
    comptime First = Self.T
    comptime Second = Self.V
    comptime Keep = _Retained[Self.T, Self.G.Element[Self.V], Self.paired, Self.selected]
    comptime Out = Self.G.Mapped[Self.V, Self.Keep]
    comptime Error = Self.G.MapError[Self.V, Self.Keep]
    def call(self, var value: Self.T, var produced: Self.V) raises Self.Error -> Self.Out:
        return Self.G.map(Self.Keep(value^), produced^)


# The family-specific finishing map is supplied to the shared callable kernel.
comptime _EffectRetain[T: Movable & Deinitable, G: Functor, C: BorrowCallContract & Movable & Deinitable, selected: Bool = False, paired: Bool = False,
                     Finish: Binary & Defaultable = _MapRetained[T, G, C.Result, selected, paired]] = _Retain[T, C, Finish]
