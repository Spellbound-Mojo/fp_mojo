"""Stack-safe effectful iteration through the family's existing dependent fold."""
from std.iter import Iterator
from std.builtin.rebind import downcast
from fp.adt.data import _ChoiceType
from fp.data.control import ControlFlow, Continue, Break, _ControlShape
from fp.callables.protocols import UnaryContract, MutableBinary, Unary
from fp.callables.invoke import RepeatableUnary
from fp.callables._receiver import _unary_repeated_as
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import Monad, _LiveAccumulator, _map_as
from .contracts import _EffectFold
from ._primitive_contracts import MapContract
from ._effect_combinators import _fold_effect


@fieldwise_init
struct _LoopTicks(Iterator, Copyable, Defaultable):
    """An unbounded unit source; std.itertools.repeat requires a finite count."""
    comptime Element = NoneType
    def __next__(mut self) raises StopIteration -> NoneType:
        return None


struct _ContinueLive[B: Movable & Deinitable, A: Movable & Deinitable](_LiveAccumulator):
    comptime Acc = ControlFlow[Self.B, Self.A]
    @staticmethod
    def live(ref value: Self.Acc) -> Bool:
        return value.isa[Continue[Self.A]]()


@fieldwise_init
struct _TailRecStep[B: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](MutableBinary):
    var function: Self.F
    comptime First = ControlFlow[Self.B, Self.F.Arg]
    comptime Second = NoneType
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_mut(mut self, var first: Self.First, var tick: NoneType) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        # The dependent fold calls this only for live Continue branches.
        var next_value = first^.unwrap[Continue[Self.F.Arg]]().into_payload()
        return _unary_repeated_as[Self.Error](self.function, next_value^)


@fieldwise_init
struct _LoopResult[B: Movable & Deinitable, A: Movable & Deinitable](Unary, Copyable, Defaultable):
    comptime Arg = ControlFlow[Self.B, Self.A]
    comptime Out = Self.B
    def call(self, var value: Self.Arg) -> Self.Out:
        # The source never exhausts: a successful fold finishes only on Break.
        return value^.unwrap[Break[Self.B]]().into_payload()


struct TailRecContract[I: Monad, F: UnaryContract & Movable & Deinitable]:
    """Admission and exact types for a step-driven effectful loop.

    Parameters:
        I: The Monad whose dependent fold sequences the steps.
        F: A repeatable callback from A to I's carrier of ControlFlow[B, A].
    """
    comptime _Shape = downcast[downcast[Self.I.Element[Self.F.Out], _ChoiceType].Of, _ControlShape]
    comptime Value = Self._Shape.BreakValue
    """The final Break payload type, inferred from the step's carrier."""
    comptime _Step = _TailRecStep[Self.Value, Self.F]
    comptime _Live = _ContinueLive[Self.Value, Self.F.Arg]
    comptime _Fold = _EffectFold[Self.I, _LoopTicks, Self._Step, Self._Live]
    comptime _Finish = _LoopResult[Self.Value, Self.F.Arg]
    comptime _Map = MapContract[Self.I, Self._Fold.Out, Self._Finish]
    comptime Error = _CommonError[Self._Fold.Error, Self._Map.Error]
    """The exact construction error, separate from deferred run errors."""
    comptime Compatible = (
        Self.I.CarrierCompatible[Self.F.Out] and
        Self.I.Element[Self.F.Out] == ControlFlow[Self.Value, Self.F.Arg] and
        RepeatableUnary[Self.F] and Self._Fold.Compatible and Self._Map.InvocationCompatible and
        _ErrorCompatible[Self.Error, Self._Fold.Error] and _ErrorCompatible[Self.Error, Self._Map.Error]
    )
    """Exact state/result shape and the family's fold, map and error admission."""
    comptime Out = Self._Map.Out
    """The family's carrier of the final Break payload."""


def tail_rec_m[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Monad](
    var step: F, var initial: A
) raises TailRecContract[I, F].Error -> TailRecContract[I, F].Out where A == F.Arg and TailRecContract[I, F].Compatible:
    """Repeat effectful steps until Break, using constant native call-stack space.

    A step consumes A and returns an effect of ControlFlow[B, A]. Continue
    supplies the next state; Break supplies the result. Failure or absence
    stops that branch. The family retains its branching order and deferred
    execution; a branching family may require copies and grow its result set.
    No trampoline or recursive callback chain is introduced: this delegates
    to the existing effectful fold and its native while loop. Custom families
    must provide a stack-safe dependent fold to satisfy the same guarantee.

    Parameters:
        A: The initial state type, inferred with its native origins.
        F: A shared or mutable step, called only for live Continue branches.
        I: The selected Monad family, including its existing fold restrictions.

    Args:
        step: The callback, consumed; results and state may be move-only.
        initial: The first state, consumed.

    Returns:
        The effect's carrier of B, or its existing failure/absence outcome.

    Raises:
        The exact compatible native error, preserving the family's timing.
    """
    comptime C = TailRecContract[I, F]
    var folded = _fold_effect[I, _LoopTicks, C._Step, C._Live, C.Error](
        C._Step(step^), C._Live.Acc(Continue(initial^)), _LoopTicks())
    return _map_as[C.Error, I](C._Finish(), folded^)


def tail_rec_m[A: Movable & Deinitable, R: Movable & Deinitable, //, I: Monad, F: _Unary[A, R]](var step: F, var initial: A
) raises TailRecContract[I, NativeUnary[A, R, Never, F, False]].Error -> TailRecContract[I, NativeUnary[A, R, Never, F, False]].Out where TailRecContract[I, NativeUnary[A, R, Never, F, False]].Compatible:
    """Loop with an owned native consuming function or closure."""
    return tail_rec_m[I](NativeUnary[A, R, Never, F, False](step^), initial^)


def tail_rec_m[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Monad, F: _RaisingUnary[A, R, E]](var step: F, var initial: A
) raises TailRecContract[I, NativeUnary[A, R, E, F, True]].Error -> TailRecContract[I, NativeUnary[A, R, E, F, True]].Out where TailRecContract[I, NativeUnary[A, R, E, F, True]].Compatible:
    """Loop with an owned native consuming function or closure."""
    return tail_rec_m[I](NativeUnary[A, R, E, F, True](step^), initial^)
