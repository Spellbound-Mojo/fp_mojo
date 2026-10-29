# error: cannot call function that may raise
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Raised(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result: raise value
def main(): _ = observed[ListFamily,OptionalFamily](List[Int]([1]),Raised())
