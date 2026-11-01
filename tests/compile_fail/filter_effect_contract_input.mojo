# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Text(BorrowCallable):
    comptime Payload = String
    comptime Result = Optional[Bool]
    def invoke(self, value: String) -> Self.Result: return Optional(True)
def main(): _ = filtered[ListFamily,OptionalFamily](List[Int]([1,2]),Text())
