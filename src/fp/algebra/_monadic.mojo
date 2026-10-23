"""Dependent accumulation through a family's map and bind.

State traversal and effectful folds share this driver. Preparation happens once
per source element; binding visits each live accumulator in the family's order.
"""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import UnaryContract, BinaryContract, Unary, OnceUnary, MutableUnary
from fp.callables.invoke import RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _unary_repeated_as, _binary_repeated_as
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Monad, _LiveAccumulator, _Item, _iterator, _next_item


@fieldwise_init
struct _ProbeShape[K: _LiveAccumulator](UnaryContract):
    comptime Arg = Self.K.Acc
    comptime Out = Self.K.Acc


@fieldwise_init
struct _Probe[K: _LiveAccumulator, o: MutOrigin](Unary):
    var live: Pointer[Bool, Self.o]
    comptime Arg = Self.K.Acc
    comptime Out = Self.K.Acc
    def call(self, var arg: Self.Arg) -> Self.Out:
        if Self.K.live(arg):
            self.live[] = True
        return arg^


@fieldwise_init
struct _StepShape[M: Monad, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](UnaryContract):
    comptime Arg = Self.K.Acc
    comptime Out = Self.M._Joined[Self.M.Pure[Self.K.Acc], Self.F.Out]
    comptime Error = Self.F.Error


@fieldwise_init
struct _Step[M: Monad, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, o: MutOrigin](
    OnceUnary, MutableUnary where conforms_to(F.Second, Copyable)
):
    var function: Pointer[Self.F, Self.o]
    var item: Self.F.Second
    comptime Arg = Self.K.Acc
    comptime Out = Self.M._Joined[Self.M.Pure[Self.K.Acc], Self.F.Out]
    comptime Error = Self.F.Error

    @staticmethod
    def _apply(mut function: Self.F, var arg: Self.Arg, var item: Self.F.Second) raises Self.Error -> Self.Out:
        comptime assert Self.F.First == Self.Arg
        comptime assert RepeatableBinary[Self.F], "fold_effect: step must be repeatable"
        if not Self.K.live(arg):
            return Self.M._join_left[Self.M.Pure[Self.K.Acc], Self.F.Out](Self.M.pure(arg^))
        var produced = _binary_repeated_as[Self.Error](function, rebind_var[Self.F.First](arg^), item^)
        return Self.M._join_right[Self.M.Pure[Self.K.Acc], Self.F.Out](produced^)

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self._apply(self.function[], arg^, self.item^)

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime C = downcast[Self.F.Second, Copyable & Deinitable]
        var item = rebind_var[Self.F.Second](rebind[C](self.item).copy())
        return Self._apply(self.function[], arg^, item^)


struct _BindLoop[M: Monad, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]:
    comptime Acc = Self.M.Pure[Self.K.Acc]
    comptime Error = _CommonError[Self.P.Error, _CommonError[
        Self.M.MapError[Self.Acc, _ProbeShape[Self.K]],
        Self.M.BindError[Self.Acc, _StepShape[Self.M, Self.F, Self.K]]]]


def _bind_loop[M: Monad, V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable,
               F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](
    var prepare: P, var step: F, var initial: K.Acc, var source: V
) raises _BindLoop[M, P, F, K].Error -> M.Pure[K.Acc]:
    comptime E = _BindLoop[M, P, F, K].Error
    comptime Acc = M.Pure[K.Acc]
    comptime assert RepeatableUnary[P] and RepeatableBinary[F], "fold_effect: callbacks must be repeatable"
    comptime assert P.Arg == _Item[V] and P.Out == F.Second and F.First == K.Acc, "fold_effect: incompatible step arguments"
    comptime assert M.Element[F.Out] == K.Acc, "fold_effect: step must preserve the accumulator type"
    comptime assert _ErrorCompatible[E, P.Error] and _ErrorCompatible[E, F.Error], "fold_effect: incompatible native errors"
    var iterator = _iterator(source^)
    var result = M.pure(initial^)
    while True:
        var live = False
        comptime Probe = _Probe[K, origin_of(live)]
        comptime assert M.Mapped[Acc, Probe] == Acc, "fold_effect: eager carrier must keep one type across steps"
        comptime assert M.MapError[Acc, Probe] == M.MapError[Acc, _ProbeShape[K]]
        try:
            result = rebind_var[Acc](M.map(Probe(Pointer(to=live)), result^))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
        if not live:
            return result^
        var item = _next_item[V](iterator)
        if not item:
            return result^
        var prepared = _unary_repeated_as[E](prepare, rebind_var[P.Arg](item.unsafe_take()))
        comptime Step = _Step[M, F, K, origin_of(step)]
        comptime assert M.Bound[Acc, Step] == Acc, "fold_effect: eager carrier must keep one type across steps"
        comptime assert M.BindError[Acc, Step] == M.BindError[Acc, _StepShape[M, F, K]]
        try:
            result = rebind_var[Acc](M.flat_map(Step(Pointer(to=step), rebind_var[F.Second](prepared^)), result^))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
