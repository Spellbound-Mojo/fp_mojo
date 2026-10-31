# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Owner(Movable):
    var value: Int
@fieldwise_init
struct Branch(BorrowCallable):
    comptime Payload = Owner
    comptime Result = List[Int]
    def invoke(self, value: Owner) -> Self.Result: return List[Int]([1,2])
def main():
    comptime assert not TraverseTapContract[OptionalFamily,ListFamily,Optional[Owner],Branch].RetentionCompatible
    _ = observed[OptionalFamily,ListFamily](Optional(Owner(3)),Branch())
