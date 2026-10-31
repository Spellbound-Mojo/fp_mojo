# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Metadata(BorrowCallContract, Movable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
def main():
    comptime assert not FilterEffectContract[OptionalFamily,OptionalFamily,Optional[Int],Metadata].ReceiverCompatible
    _ = filtered[OptionalFamily,OptionalFamily](Optional(2),Metadata())
