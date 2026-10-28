"""Internal shared receiver adaptation for callbacks with origin-indexed output.

Entry points borrow these values and own the resulting fixed-signature view.
The view carries the original receiver's origin, including through lazy or
otherwise deferred results. Existing owned Unary callbacks keep their contract.
"""
from fp.callables.protocols import Unary, UnaryContract, BorrowCallable

trait _UnaryViewable(UnaryContract, Movable, Deinitable):
    comptime _View[o: ImmOrigin]: Unary
    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]: ...

trait _BorrowViewable(BorrowCallable):
    # Borrowing-operand callbacks have a distinct contract from owned unary calls.
    comptime _BorrowView[o: ImmOrigin]: BorrowCallable
    def _borrow_view[o: ImmOrigin](ref[o] self) -> Self._BorrowView[o]: ...
