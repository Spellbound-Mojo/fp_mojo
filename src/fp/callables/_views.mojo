"""Internal shared receiver adaptation for callbacks with origin-indexed output.

Entry points borrow these values and own the resulting fixed-signature view.
The view carries the original receiver's origin, including through lazy or
otherwise deferred results. Existing owned callbacks keep their contract.
"""
from fp.callables.protocols import Unary, UnaryContract, BorrowCallable, Binary

trait _BorrowedView:
    # Marks callbacks that borrow their receiver or native function through an
    # origin. Consumers that erase a callback's type reject these views, since
    # erasure would drop the origin that keeps the borrowed callback alive.
    pass


trait _BinaryViewable(Binary):
    # Fixed-output Binary needs no origin-indexed projection. Opt in only the
    # standard wrappers: borrowing every Binary would change the established
    # receiver preference of custom shared/mutable implicit-copy callables.
    pass

trait _UnaryViewable(UnaryContract, Movable, Deinitable):
    comptime _View[o: ImmOrigin]: Unary
    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]: ...

trait _BorrowViewable(BorrowCallable):
    # Borrowing-operand callbacks have a distinct contract from owned unary calls.
    comptime _BorrowView[o: ImmOrigin]: BorrowCallable
    def _borrow_view[o: ImmOrigin](ref[o] self) -> Self._BorrowView[o]: ...
