"""Result error policies and accumulation over the shared native pull loop."""
from .protocols import Semigroup, _Accumulate, _map_accumulate, _start_as
from fp.data._result import Result, Ok, _result_map2
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


@fieldwise_init
struct _AccumulatePair[K: _Accumulate](Binary, Copyable, Defaultable):
    comptime First = Self.K.Acc
    comptime Second = Self.K.Item
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return Self.K.combine(first^, second^)


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
