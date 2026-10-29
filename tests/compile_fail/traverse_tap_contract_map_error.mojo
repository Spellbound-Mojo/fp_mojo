# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
from algebra_support.external import PublicMonad
@fieldwise_init
struct Raised(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    comptime Failure = String
    def invoke(self, value: Int) raises String -> Self.Result: raise String("observer")
def main() raises:
    comptime G = PublicMonad[OptionalFamily,1]
    comptime assert not TraverseTapContract[ListFamily,G,List[Int],Raised].RetentionCompatible
    _ = observed[ListFamily,G](List[Int]([1]),Raised())
