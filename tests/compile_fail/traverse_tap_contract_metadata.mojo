# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Metadata(BorrowCallContract, Movable):
    comptime Payload = Int
    comptime Result = Optional[Int]
def main():
    comptime assert not TraverseTapContract[OptionalFamily,OptionalFamily,Optional[Int],Metadata].ReceiverCompatible
    _ = observed[OptionalFamily,OptionalFamily](Optional(1),Metadata())
