# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    def invoke(self, value: Int) -> Self.Result: return Optional(value)
def main(): _ = filtered[ListFamily,OptionalFamily](List[Int]([1,2]),Wrong())
