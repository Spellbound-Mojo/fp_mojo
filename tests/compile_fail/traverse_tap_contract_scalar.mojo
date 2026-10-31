# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Scalar(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, value: Int) -> Int: return value
def main(): _ = observed[ListFamily,OptionalFamily](List[Int]([1,2]),Scalar())
