# error: cannot call function that may raise
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Raised(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result: raise value
def main(): _ = filtered[ListFamily,OptionalFamily](List[Int]([1]),Raised())
