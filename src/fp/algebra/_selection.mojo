"""Selection callbacks shared by filtering and the native filterable families.

They sit below both `filtering` and the families, so the families can derive
`filter` from `filter_map` without importing the free operations.
"""
from std.builtin.rebind import downcast
from fp.callables.protocols import BorrowCallContract, BorrowCallable, Unary, UnaryContract, MutableUnary
from fp.callables.invoke import RepeatableBorrow
from fp.callables._transforms import _selected
from fp.iteration._callbacks import _predicate_callable, _predicate_repeated
from .protocols import _Accumulate


@fieldwise_init
struct _Select[T: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](
    UnaryContract, Movable, Deinitable,
    Unary where conforms_to(P, BorrowCallable), MutableUnary where RepeatableBorrow[P]
):
    var predicate: Self.P
    comptime Arg = Self.T
    comptime Out = Optional[Self.T]
    comptime Error = Self.P.Failure
    def call(self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.P, BorrowCallable)
        comptime Shared = downcast[Self.P, BorrowCallable]
        var accepted = _predicate_callable[Self.T, Shared, Self.Error](arg, rebind[Shared](self.predicate))
        return _selected(arg^, accepted)

    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert RepeatableBorrow[Self.P] and Self.P.Payload == Self.T and Self.P.Result == Bool
        var accepted = _predicate_repeated[Self.T, Self.P, origin_of(self.predicate), Self.Error](arg, Pointer(to=self.predicate))
        return _selected(arg^, accepted)


struct _Keep[K: _Accumulate](_Accumulate):
    """Discard absent payloads; reuse the native accumulator's insertion rule."""
    comptime Acc = Self.K.Acc
    comptime Item = Optional[Self.K.Item]
    comptime Error = Self.K.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Self.K.start()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Self.K.live(acc)
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if item:
            return Self.K.combine(acc^, item.unsafe_take())
        return acc^
