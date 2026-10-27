"""Sequencing continuations shared by bind, traversal and lazy iteration."""
from ._primitive_contracts import MapContract
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import Unary, OnceUnary, MutableUnary, BorrowCallContract, BorrowCallable, Binary, ThunkContract
from fp.callables.invoke import invoke_borrowed, RepeatableThunk
from fp.callables._receiver import _borrow_once_as, _borrow_repeated_as, _RepeatableBorrow, _binary_once_as, _ThunkView, _thunk_once_as
from fp.callables._transforms import _Retained
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import Functor, Monad
from fp.callables._retention import _Retain


@fieldwise_init
struct _MapRetained[T: Movable & Deinitable, G: Functor, V: Movable & Deinitable,
                    selected: Bool, paired: Bool](Binary, Defaultable):
    """Finish ordinary retention by mapping the original into each success."""
    comptime First = Self.T
    comptime Second = Self.V
    comptime Keep = _Retained[Self.T, Self.G.Element[Self.V], Self.paired, Self.selected]
    comptime _Operation = MapContract[Self.G, Self.V, Self.Keep]
    comptime Out = Self._Operation.Out
    comptime Error = Self._Operation.Error
    def call(self, var value: Self.T, var produced: Self.V) raises Self.Error -> Self.Out:
        return Self.G.map(Self.Keep(value^), produced^)


# The family-specific finishing map is supplied to the shared callable kernel.
comptime _EffectRetain[T: Movable & Deinitable, G: Functor, C: BorrowCallContract & Movable & Deinitable, selected: Bool = False, paired: Bool = False,
                     Finish: Binary & Defaultable = _MapRetained[T, G, C.Result, selected, paired]] = _Retain[T, C, Finish]


def _choose_effect[G: Monad, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    condition: Bool, var on_true: L, var on_false: R
) raises _CommonError[L.Error, R.Error] -> G._Joined[L.Out, R.Out]:
    comptime E = _CommonError[L.Error, R.Error]
    comptime assert _ErrorCompatible[E, L.Error] and _ErrorCompatible[E, R.Error], "if_effect: incompatible native errors"
    comptime assert G.Element[L.Out] == G.Element[R.Out], "if_effect: branches must have the same payload type"
    if condition:
        return G._join_left[L.Out, R.Out](_thunk_once_as[E](on_true^))
    return G._join_right[L.Out, R.Out](_thunk_once_as[E](on_false^))


@fieldwise_init
struct _IfEffect[G: Monad, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableThunk[L] and RepeatableThunk[R]
):
    var on_true: Self.L
    var on_false: Self.R
    comptime Arg = Bool
    comptime Out = Self.G._Joined[Self.L.Out, Self.R.Out]
    comptime Error = _CommonError[Self.L.Error, Self.R.Error]
    def call_once(deinit self, var arg: Bool) raises Self.Error -> Self.Out:
        return _choose_effect[Self.G](arg, self.on_true^, self.on_false^)
    def call_mut(mut self, var arg: Bool) raises Self.Error -> Self.Out:
        var left = _ThunkView(Pointer(to=self.on_true))
        var right = _ThunkView(Pointer(to=self.on_false))
        return _choose_effect[Self.G](arg, left^, right^)
