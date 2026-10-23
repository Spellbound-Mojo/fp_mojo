"""Shared predicate-result transformations; invocation keeps its native owner."""
from .protocols import BorrowCallable
from .invoke import invoke_borrowed


def _filter_decision[inverted: Bool](accepted: Bool) -> Bool:
    return accepted != inverted


@fieldwise_init
struct _Negated[C: BorrowCallable](BorrowCallable):
    var predicate: Self.C
    comptime Payload = Self.C.Payload
    comptime Result = Bool
    comptime Failure = Self.C.Failure

    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Bool:
        comptime assert Self.C.Result == Bool, "filter_not: Bool predicate required"
        return _filter_decision[True](rebind[Bool](invoke_borrowed[Self.Failure](payload, self.predicate)))


comptime _FilterPredicate[C: BorrowCallable, inverted: Bool] = _Negated[C] if inverted else C
