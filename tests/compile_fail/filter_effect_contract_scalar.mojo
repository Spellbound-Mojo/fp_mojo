# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Scalar(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, value: Int) -> Bool: return True
def main(): _ = filtered[ListFamily,OptionalFamily](List[Int]([1,2]),Scalar())
