# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    def invoke_once(deinit self, ref value: Int) -> Self.Result: return Optional(value)
def main(): _ = observed[ListFamily,OptionalFamily](List[Int]([1,2]),Once())
