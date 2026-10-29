# error: constraint
from fp.iteration import iterated
from fp.callables import BorrowCallable
@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    def invoke(self, value: Int) -> Self.Result: return Optional(value)
def main(): _ = iterated(range(2)).filter_effect(Wrong())
