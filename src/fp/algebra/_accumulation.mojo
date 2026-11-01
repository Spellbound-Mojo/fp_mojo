"""Accumulation policies shared by pure and effectful terminals."""
from ._primitive_contracts import MapContract
from .protocols import Semigroup, Monoid, Monad, _Accumulate, _SemigroupBinary, _BindFirst, _map_as, _LiveAccumulator
from fp.callables.protocols import UnaryContract, MutableBinary, Binary, BorrowCallable
from fp.callables.invoke import RepeatableUnary, invoke_borrowed
from std.builtin.rebind import downcast
from fp.callables._receiver import _unary_repeated_as
from fp._internal.errors import _CommonError, _ErrorCompatible


struct _Combine[M: Monoid](_Accumulate):
    comptime Acc = Self.M.Value
    comptime Item = Self.M.Value
    comptime Error = Self.M.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Self.M.empty()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        return _SemigroupBinary[Self.M]().call(acc^, item^)


struct _FirstPresent[T: Movable & Deinitable](_Accumulate):
    comptime Acc = Optional[Self.T]
    comptime Item = Self.Acc
    @staticmethod
    def start() -> Self.Acc:
        return None
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return not acc
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        return item^


struct _OptionalCombine[S: Semigroup](_Accumulate):
    comptime Acc = Optional[Self.S.Value]
    comptime Item = Self.S.Value
    comptime Error = Self.S.Error
    @staticmethod
    def start() -> Self.Acc: return None
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool: return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if not acc: return Optional(item^)
        return Optional(_SemigroupBinary[Self.S]().call(acc.unsafe_take(), item^))


@fieldwise_init
struct _FoldMappedStep[G: Monad, M: Monoid, F: UnaryContract & Movable & Deinitable](MutableBinary):
    var function: Self.F
    comptime First = Self.M.Value
    comptime Second = Self.F.Arg
    comptime Combine = _BindFirst[_SemigroupBinary[Self.M]]
    comptime _Operation = MapContract[Self.G, Self.F.Out, Self.Combine]
    comptime Out = Self._Operation.Out
    comptime Error = _CommonError[Self.F.Error, Self._Operation.Error]
    def call_mut(mut self, var first: Self.First, var item: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime assert Self.G.Element[Self.F.Out] == Self.M.Value
        comptime assert Self.G.MapCompatible[Self.F.Out, Self.Combine]
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.G.MapError[Self.F.Out, Self.Combine]], "fold_map_effect: incompatible native errors"
        var produced = _unary_repeated_as[Self.Error](self.function, item^)
        # The canonical owned partial copies the accumulator only when the
        # selected family requires repeated branches; single-use maps move it.
        var combine = Self.Combine(_SemigroupBinary[Self.M](), first^)
        return _map_as[Self.Error, Self.G](combine^, produced^)


@fieldwise_init
struct _SearchStep[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](MutableBinary):
    var function: Self.F
    comptime First = Optional[Self.A]
    comptime Second = Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_mut(mut self, var first: Self.First, var item: Self.Second) raises Self.Error -> Self.Out:
        # The dependent fold calls only live (absent) accumulators. Successful
        # branches are retained by that driver without evaluating this step.
        comptime assert RepeatableUnary[Self.F]
        return _unary_repeated_as[Self.Error](self.function, item^)


struct _BoolLive[all_values: Bool](_LiveAccumulator):
    comptime Acc = Bool
    @staticmethod
    def live(ref acc: Bool) -> Bool: return acc == Self.all_values


@fieldwise_init
struct _PredicateStep[C: BorrowCallable](Binary):
    var predicate: Self.C
    comptime First = Bool
    comptime Second = downcast[Self.C.Payload, Movable & Deinitable]
    comptime Out = Self.C.Result
    comptime Error = Self.C.Failure
    def call(self, var first: Bool, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert Self.Second == Self.C.Payload
        return invoke_borrowed[Self.Error](second, self.predicate)
