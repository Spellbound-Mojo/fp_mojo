# error: constraint
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
@fieldwise_init
struct Owner(Movable):
    var value: Int
@fieldwise_init
struct Branch(BorrowCallable):
    comptime Payload = Owner
    comptime Result = List[Bool]
    def invoke(self, value: Owner) -> Self.Result: return List[Bool]([False,True])
def main():
    comptime assert not FilterEffectContract[OptionalFamily,ListFamily,Optional[Owner],Branch].RetentionCompatible
    _ = filtered[OptionalFamily,ListFamily](Optional(Owner(3)),Branch())
