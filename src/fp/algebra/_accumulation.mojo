"""Accumulation policies shared by pure and effectful terminals."""
from .protocols import Semigroup, Monoid, _Accumulate, _SemigroupBinary


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
