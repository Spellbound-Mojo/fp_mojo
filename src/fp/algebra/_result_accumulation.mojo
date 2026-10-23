"""Result error policies and accumulation over the shared native pull loop."""
from .protocols import Semigroup, _Accumulate, _map_accumulate, _start_as, _AccumulatePair
from fp.data._result import Result, Ok, Err, _transform_result_owned
from std.builtin.rebind import rebind_var
from fp.callables.protocols import BinaryContract, ThunkContract
from fp.callables.invoke import call_once
from fp.callables._receiver import _thunk_once_as
from fp._internal.errors import _propagate_error
from fp.callables.protocols import UnaryContract, Binary
from fp.callables._transforms import _ValueThunk
from fp._internal.errors import _CommonError, _ErrorCompatible


trait _ResultPolicy(Semigroup):
    comptime Accumulate: Bool


struct _FirstError[E: Movable & Deinitable](_ResultPolicy):
    comptime Value = Self.E
    comptime Error = Never
    comptime Accumulate = False
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        return left^


struct _AccumulatingErrors[S: Semigroup](_ResultPolicy):
    comptime Value = Self.S.Value
    comptime Error = Self.S.Error
    comptime Accumulate = True
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        return Self.S.combine(left^, right^)


struct _ResultAccumulator[K: _Accumulate, P: _ResultPolicy](_Accumulate):
    comptime Acc = Result[Self.K.Acc, Self.P.Value]
    comptime Item = Result[Self.K.Item, Self.P.Value]
    comptime Error = _CommonError[Self.P.Error, Self.K.Error]
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        comptime assert _ErrorCompatible[Self.Error, Self.K.Error]
        return Self.Acc(Ok(_start_as[Self.Error, Self.K]()))
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        if acc.is_err():
            return Self.P.Accumulate
        return Self.K.live(acc._ok().value)
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if not Self.live(acc):
            return acc^
        return _result_map2[Self.P.Value, P=Self.P, X=Self.Error](
            _AccumulatePair[Self.K](), acc^, _ValueThunk(item^))


def _result_loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                 K: _Accumulate, P: _ResultPolicy, X: Movable & Deinitable = _CommonError[F.Error, _ResultAccumulator[K, P].Error]](var f: F, var source: V
) raises X -> Result[K.Acc, P.Value]:
    comptime A = _ResultAccumulator[K, P]
    comptime assert _ErrorCompatible[X, A.Error]
    return _map_accumulate[V, F, A, X](f^, source^, _start_as[X, A]())


@fieldwise_init
struct _ResultRight[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable](Movable):
    """Context for the left success: produce the right operand, then combine."""
    var f: Self.F
    var right: Self.R
    comptime Error = Self.X
    def apply(deinit self, var first: Self.F.First) raises Self.Error -> Result[Self.F.Out, Self.S]:
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.R.Error]
        var second = rebind_var[Result[Self.F.Second, Self.S]](_thunk_once_as[Self.Error](self.right^))
        try:
            return _transform_result_owned[Self.F.Second, Self.S, Self.F.Out, Self.S, Self.F.Error, True, True,
                Self.F.Second, Self.F.Out, _ResultLeft[Self.F, Self.S], _result_combine[Self.F, Self.S]](
                second^, _ResultLeft[Self.F, Self.S](self.f^, first^))
        except error:
            _propagate_error[Self.Error](error^)


@fieldwise_init
struct _ResultLeft[F: BinaryContract & Movable & Deinitable, S: Movable & Deinitable](Movable):
    """Context for the right success: the callback and the left payload."""
    var f: Self.F
    var first: Self.F.First
    def apply(deinit self, var second: Self.F.Second) raises Self.F.Error -> Self.F.Out:
        return call_once(self.f^, self.first^, second^)


def _result_right[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable](
    var first: F.First, var context: _ResultRight[F, R, S, X]
) raises X capturing -> Result[F.Out, S]:
    return context^.apply(first^)


def _result_combine[F: BinaryContract & Movable & Deinitable, S: Movable & Deinitable](
    var second: F.Second, var context: _ResultLeft[F, S]
) raises F.Error capturing -> F.Out:
    return context^.apply(second^)


def _result_map2[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, P: _ResultPolicy = _FirstError[E], X: Movable & Deinitable = _CommonError[_CommonError[F.Error, R.Error], P.Error]](
    var function: F, var left: Result[F.First, E], var right: R
) raises X -> Result[F.Out, E]:
    """Canonical Result combination; the policy controls stored errors only."""
    comptime assert R.Out == Result[F.Second, E], "map2: same family required"
    comptime assert _ErrorCompatible[X, F.Error] and _ErrorCompatible[X, R.Error], "map2: incompatible native errors"
    comptime assert P.Value == E
    comptime assert _ErrorCompatible[X, P.Error]
    comptime if P.Accumulate:
        if left.is_err():
            var second = rebind_var[Result[F.Second, E]](_thunk_once_as[X](right^))
            var error = left^._take_err()
            if second.is_err():
                try:
                    error = rebind_var[E](P.combine(rebind_var[P.Value](error^), rebind_var[P.Value](second^._take_err())))
                except raised:
                    _propagate_error[X](raised^)
            return Result[F.Out, E](Err(error^))
    return _transform_result_owned[F.First, E, F.Out, E, X, True, False, F.First, Result[F.Out, E],
        _ResultRight[F, R, E, X], _result_right[F, R, E, X]](left^, _ResultRight[F, R, E, X](function^, right^))
