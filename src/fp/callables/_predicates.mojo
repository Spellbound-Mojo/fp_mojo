"""Shared predicate-result transformations; invocation keeps its native owner."""
from std.builtin.rebind import downcast
from .protocols import BorrowCallContract, BorrowCallable, BorrowMutableCallable
from .invoke import invoke_borrowed, invoke_borrowed_repeated, RepeatableBorrow


def _filter_decision[inverted: Bool](accepted: Bool) -> Bool:
    return accepted != inverted


@fieldwise_init
struct _Negated[C: BorrowCallContract & Movable & Deinitable](
    BorrowCallContract, Movable, Deinitable,
    BorrowCallable where conforms_to(C, BorrowCallable), BorrowMutableCallable where RepeatableBorrow[C]
):
    var predicate: Self.C
    comptime Payload = Self.C.Payload
    comptime Result = Bool
    comptime Failure = Self.C.Failure

    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Bool:
        comptime assert Self.C.Result == Bool, "filter_not: Bool predicate required"
        comptime assert conforms_to(Self.C, BorrowCallable)
        comptime Shared = downcast[Self.C, BorrowCallable]
        return _filter_decision[True](rebind[Bool](invoke_borrowed[Self.Failure](payload, rebind[Shared](self.predicate))))

    def invoke_mut(mut self, ref payload: Self.Payload) raises Self.Failure capturing -> Bool:
        comptime assert RepeatableBorrow[Self.C] and Self.C.Result == Bool, "filter_not: repeatable Bool predicate required"
        return _filter_decision[True](rebind[Bool](invoke_borrowed_repeated[Self.Failure](payload, self.predicate)))


comptime _FilterPredicate[C: BorrowCallContract & Movable & Deinitable, inverted: Bool] = _Negated[C] if inverted else C
