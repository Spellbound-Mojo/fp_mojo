# error: constraint
from fp.iteration import iterated
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    def invoke_once(deinit self, ref value: Int) raises Never capturing -> Self.Result: return Optional(value)
def main(): _ = iterated(range(2)).traverse_tap(Once())
