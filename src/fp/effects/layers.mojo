"""OptionalT and ResultT: a base carrier of Optional[A] or Result[A, E].

A layer value is the base carrier itself and runs with the base's `run`. `map`
maps the inner carrier through the inner family's own `map`. `flat_map` and
`map2_lazy` bind the base: an absent value or a stored error skips the callback
and the right operand, keeping the base's earlier effects. The right operand is
produced at most once. Over IdentityFamily the aliases are the native Optional
and Result families.
"""
from std.builtin.rebind import rebind_var, rebind, downcast
from fp.algebra.protocols import (Monad, Applicative, _Lifting, _Accumulate, _Present, _BindFirst, _Lazy, _UnaryView)
from fp.algebra.instances import IdentityFamily, OptionalFamily, ResultFamily, _OkOf
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, OnceUnary, MutableUnary
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary
from fp.data._result import Result, Ok, Err
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from ._adapt import _map_as


comptime _LAYER = "transformer: different inner family or error type"
comptime _LAYER_BIND = "transformer bind: different inner family or error type"


@fieldwise_init
struct _InnerMap[N: Applicative, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Map a layer's inner Optional or Result carrier with the inner family."""
    var function: Self.F
    comptime Arg = Self.N.Pure[Self.F.Arg]
    comptime Out = Self.N.Mapped[Self.N.Pure[Self.F.Arg], Self.F]
    comptime Error = Self.N.MapError[Self.N.Pure[Self.F.Arg], Self.F]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self.N.map(self.function^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime View = _UnaryView[Self.F, origin_of(self.function)]
        comptime assert Self.N.Mapped[Self.Arg, View] == Self.Out
        comptime assert _ErrorCompatible[Self.Error, Self.N.MapError[Self.Arg, View]]
        return rebind_var[Self.Out](_map_as[Self.Error, Self.N](View(Pointer(to=self.function)), arg^))


@fieldwise_init
struct _OptionalGuard[M: Monad, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """OptionalT bind step: absence returns the base's pure absence; presence
    calls F, whose result is the next layer value."""
    var function: Self.F
    comptime B = OptionalFamily.Element[Self.M.Element[Self.F.Out]]
    comptime Absent = Self.M.Pure[Optional[Self.B]]
    comptime Arg = Optional[Self.F.Arg]
    comptime Out = Self.M._Joined[Self.Absent, Self.F.Out]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        if not arg:
            return Self.M._join_left[Self.Absent, Self.F.Out](Self.M.pure(Optional[Self.B]()))
        return Self.M._join_right[Self.Absent, Self.F.Out](call_once(self.function^, arg.unsafe_take()))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        if not arg:
            return Self.M._join_left[Self.Absent, Self.F.Out](Self.M.pure(Optional[Self.B]()))
        return Self.M._join_right[Self.Absent, Self.F.Out](call_repeated(self.function, arg.unsafe_take()))


@fieldwise_init
struct _ResultGuard[M: Monad, E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """ResultT bind step: a stored error returns the base's pure error; success
    calls F, whose result is the next layer value."""
    var function: Self.F
    comptime B = ResultFamily[Self.E].Element[Self.M.Element[Self.F.Out]]
    comptime Absent = Self.M.Pure[Result[Self.B, Self.E]]
    comptime Arg = Result[Self.F.Arg, Self.E]
    comptime Out = Self.M._Joined[Self.Absent, Self.F.Out]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        if arg.is_err():
            var stored = arg^._take_err()
            return Self.M._join_left[Self.Absent, Self.F.Out](Self.M.pure(Result[Self.B, Self.E](Err(stored^))))
        var value = arg^._take_ok()
        return Self.M._join_right[Self.Absent, Self.F.Out](call_once(self.function^, value^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        if arg.is_err():
            var stored = arg^._take_err()
            return Self.M._join_left[Self.Absent, Self.F.Out](Self.M.pure(Result[Self.B, Self.E](Err(stored^))))
        var value = arg^._take_ok()
        return Self.M._join_right[Self.Absent, Self.F.Out](call_repeated(self.function, value^))


@fieldwise_init
struct _OptionalCombine[M: Monad, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(F, Copyable) and conforms_to(G.Out, Copyable)
):
    """OptionalT map2 step: absence returns the base's pure absence and skips
    the right operand; presence produces it once and maps the inner combination."""
    var function: Self.F
    var right: _Lazy[Self.G]
    comptime Apply = _InnerMap[OptionalFamily, _BindFirst[Self.F]]
    comptime Absent = Self.M.Pure[Optional[Self.F.Out]]
    comptime Present = Self.M.Mapped[Self.G.Out, Self.Apply]
    comptime Arg = Optional[Self.F.First]
    comptime Out = Self.M._Joined[Self.Absent, Self.Present]
    comptime Error = _CommonError[Self.G.Error, Self.M.MapError[Self.G.Out, Self.Apply]]
    @staticmethod
    def _apply(var function: Self.F, var first: Self.F.First, var right: Self.G.Out) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.M.MapError[Self.G.Out, Self.Apply]]
        var mapped = _map_as[Self.Error, Self.M](Self.Apply(_BindFirst[Self.F](function^, first^)), right^)
        return Self.M._join_right[Self.Absent, Self.Present](mapped^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        if not arg:
            return Self.M._join_left[Self.Absent, Self.Present](Self.M.pure(Optional[Self.F.Out]()))
        var right: Self.G.Out
        try:
            right = self.right^.take()
        except error:
            _propagate_error[Self.Error](error^)
        return Self._apply(self.function^, arg.unsafe_take(), right^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.F, Copyable), "map2: repeated branches copy the callback and the right operand"
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        if not arg:
            return Self.M._join_left[Self.Absent, Self.Present](Self.M.pure(Optional[Self.F.Out]()))
        var right: Self.G.Out
        try:
            right = self.right.copy_value()
        except error:
            _propagate_error[Self.Error](error^)
        comptime C = downcast[Self.F, Copyable & Deinitable]
        var function = rebind_var[Self.F](rebind[C](self.function).copy())
        return Self._apply(function^, arg.unsafe_take(), right^)


@fieldwise_init
struct _ResultCombine[M: Monad, E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                      G: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(F, Copyable) and conforms_to(G.Out, Copyable)
):
    """ResultT map2 step: a stored error returns the base's pure error and skips
    the right operand; success produces it once and maps the inner combination."""
    var function: Self.F
    var right: _Lazy[Self.G]
    comptime Apply = _InnerMap[ResultFamily[Self.E], _BindFirst[Self.F]]
    comptime Absent = Self.M.Pure[Result[Self.F.Out, Self.E]]
    comptime Present = Self.M.Mapped[Self.G.Out, Self.Apply]
    comptime Arg = Result[Self.F.First, Self.E]
    comptime Out = Self.M._Joined[Self.Absent, Self.Present]
    comptime Error = _CommonError[Self.G.Error, Self.M.MapError[Self.G.Out, Self.Apply]]
    @staticmethod
    def _apply(var function: Self.F, var first: Self.F.First, var right: Self.G.Out) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.M.MapError[Self.G.Out, Self.Apply]]
        var mapped = _map_as[Self.Error, Self.M](Self.Apply(_BindFirst[Self.F](function^, first^)), right^)
        return Self.M._join_right[Self.Absent, Self.Present](mapped^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        if arg.is_err():
            var stored = arg^._take_err()
            return Self.M._join_left[Self.Absent, Self.Present](Self.M.pure(Result[Self.F.Out, Self.E](Err(stored^))))
        var right: Self.G.Out
        try:
            right = self.right^.take()
        except error:
            _propagate_error[Self.Error](error^)
        return Self._apply(self.function^, arg^._take_ok(), right^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.F, Copyable), "map2: repeated branches copy the callback and the right operand"
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        if arg.is_err():
            var stored = arg^._take_err()
            return Self.M._join_left[Self.Absent, Self.Present](Self.M.pure(Result[Self.F.Out, Self.E](Err(stored^))))
        var right: Self.G.Out
        try:
            right = self.right.copy_value()
        except error:
            _propagate_error[Self.Error](error^)
        comptime C = downcast[Self.F, Copyable & Deinitable]
        var function = rebind_var[Self.F](rebind[C](self.function).copy())
        return Self._apply(function^, arg^._take_ok(), right^)


struct _OptionalAcc[K: _Accumulate](_Accumulate):
    """Accumulate inside Optional: the first absent payload ends accumulation."""
    comptime Acc = Optional[Self.K.Acc]
    comptime Item = Optional[Self.K.Item]
    comptime Error = Self.K.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Optional(Self.K.start())
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Bool(acc) and Self.K.live(acc.value())
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if not Self.live(acc):
            return acc^
        if not item:
            return Optional[Self.K.Acc]()
        return Optional(Self.K.combine(acc.unsafe_take(), item.unsafe_take()))


struct _ResultAcc[K: _Accumulate, E: Movable & Deinitable](_Accumulate):
    """Accumulate inside Result: the first stored error ends accumulation."""
    comptime Acc = Result[Self.K.Acc, Self.E]
    comptime Item = Result[Self.K.Item, Self.E]
    comptime Error = Self.K.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Result[Self.K.Acc, Self.E](Ok(Self.K.start()))
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return acc.is_ok() and Self.K.live(acc._ok().value)
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if acc.is_err():
            return acc^
        var current = acc^._take_ok()
        if not Self.K.live(current):
            return Result[Self.K.Acc, Self.E](Ok(current^))
        if item.is_err():
            return Result[Self.K.Acc, Self.E](Err(item^._take_err()))
        return Result[Self.K.Acc, Self.E](Ok(Self.K.combine(current^, item^._take_ok())))


struct _OptionalT[M: Monad](Monad, _Lifting):
    """OptionalT over a base other than Identity: a value is M's carrier of Optional[A]."""
    comptime Base = Self.M
    comptime Element[V: Movable & Deinitable] = OptionalFamily.Element[Self.M.Element[V]]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Mapped[V, _InnerMap[OptionalFamily, F]]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.MapError[V, _InnerMap[OptionalFamily, F]]
    comptime Pure[A: Movable & Deinitable] = Self.M.Pure[Optional[A]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self.M.Bound[
        V, _OptionalCombine[Self.M, F, G]]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self.M.BindError[
        V, _OptionalCombine[Self.M, F, G]]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Bound[V, _OptionalGuard[Self.M, F]]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.BindError[V, _OptionalGuard[Self.M, F]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._Looped[V, F, _OptionalAcc[K]]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopError[V, F, _OptionalAcc[K]]
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.M._Joined[L, Q]
    comptime Lifted[V: Movable & Deinitable] = Self.M.Mapped[V, _Present[Self.M.Element[V]]]
    comptime LiftError[V: Movable & Deinitable] = Self.M.MapError[V, _Present[Self.M.Element[V]]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert Self.M.Element[V] == Optional[F.Arg], _LAYER
        return Self.M.map(_InnerMap[OptionalFamily, F](f^), value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return Self.M.pure(Optional(value^))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        comptime assert Self.M.Element[V] == Optional[F.First] and Self.M.Element[G.Out] == Optional[F.Second], _LAYER
        return Self.M.flat_map(_OptionalCombine[Self.M, F, G](f^, _Lazy[G](right^)), left^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        comptime assert Self.M.Element[V] == Optional[F.Arg], _LAYER
        comptime assert Self.M.Element[F.Out] == Optional[OptionalFamily.Element[Self.M.Element[F.Out]]], _LAYER_BIND
        return Self.M.flat_map(_OptionalGuard[Self.M, F](f^), value^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return Self.M._loop[V, F, _OptionalAcc[K]](f^, source^)

    @staticmethod
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        return Self.M._join_left[L, Q](value^)

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        return Self.M._join_right[L, Q](value^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        return Self.M.map(_Present[Self.M.Element[V]](), value^)


struct _ResultT[M: Monad, E: Movable & Deinitable](Monad, _Lifting):
    """ResultT over a base other than Identity: a value is M's carrier of Result[A, E]."""
    comptime Base = Self.M
    comptime Element[V: Movable & Deinitable] = ResultFamily[Self.E].Element[Self.M.Element[V]]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Mapped[V, _InnerMap[ResultFamily[Self.E], F]]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.MapError[V, _InnerMap[ResultFamily[Self.E], F]]
    comptime Pure[A: Movable & Deinitable] = Self.M.Pure[Result[A, Self.E]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self.M.Bound[
        V, _ResultCombine[Self.M, Self.E, F, G]]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self.M.BindError[
        V, _ResultCombine[Self.M, Self.E, F, G]]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.Bound[V, _ResultGuard[Self.M, Self.E, F]]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.BindError[V, _ResultGuard[Self.M, Self.E, F]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._Looped[V, F, _ResultAcc[K, Self.E]]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopError[V, F, _ResultAcc[K, Self.E]]
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.M._Joined[L, Q]
    comptime Lifted[V: Movable & Deinitable] = Self.M.Mapped[V, _OkOf[Self.M.Element[V], Self.E]]
    comptime LiftError[V: Movable & Deinitable] = Self.M.MapError[V, _OkOf[Self.M.Element[V], Self.E]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert Self.M.Element[V] == Result[F.Arg, Self.E], _LAYER
        return Self.M.map(_InnerMap[ResultFamily[Self.E], F](f^), value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return Self.M.pure(Result[A, Self.E](Ok(value^)))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        comptime assert Self.M.Element[V] == Result[F.First, Self.E] and Self.M.Element[G.Out] == Result[F.Second, Self.E], _LAYER
        return Self.M.flat_map(_ResultCombine[Self.M, Self.E, F, G](f^, _Lazy[G](right^)), left^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        comptime assert Self.M.Element[V] == Result[F.Arg, Self.E], _LAYER
        comptime assert Self.M.Element[F.Out] == Result[ResultFamily[Self.E].Element[Self.M.Element[F.Out]], Self.E], _LAYER_BIND
        return Self.M.flat_map(_ResultGuard[Self.M, Self.E, F](f^), value^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return Self.M._loop[V, F, _ResultAcc[K, Self.E]](f^, source^)

    @staticmethod
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        return Self.M._join_left[L, Q](value^)

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        return Self.M._join_right[L, Q](value^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        return Self.M.map(_OkOf[Self.M.Element[V], Self.E](), value^)


comptime OptionalT[M: Monad]: Monad & _Lifting = OptionalFamily if M == IdentityFamily else _OptionalT[M]
"""Optional over the base Monad `M`: a value is `M`'s carrier of `Optional[A]`; over Identity, `OptionalFamily`.

A value is the base carrier itself, run with the base's `run`. An absent value
skips later callbacks and right operands and keeps the base's earlier effects.

Parameters:
    M: The base Monad.
"""

comptime ResultT[M: Monad, E: Movable & Deinitable]: Monad & _Lifting = ResultFamily[E] if M == IdentityFamily else _ResultT[M, E]
"""Result over the base Monad `M`: a value is `M`'s carrier of `Result[A, E]`; over Identity, `ResultFamily[E]`.

A stored error skips later callbacks and right operands and keeps the base's
earlier effects; it is never converted into an absence, nor a native error.

Parameters:
    M: The base Monad.
    E: The stored error type.
"""
