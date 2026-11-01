# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Raised(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = String
    def invoke(self, value: Int) raises String -> Self.Result: raise String("predicate")
def main() raises:
    comptime assert not FilterEffectContract[FailingCompaction,OptionalFamily,List[Int],Raised].ConstructionCompatible
    _ = filtered[FailingCompaction,OptionalFamily](List[Int]([1]),Raised())
