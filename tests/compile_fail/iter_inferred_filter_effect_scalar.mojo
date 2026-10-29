# error: constraint
from fp.iteration import iterated
from fp.callables import BorrowCallable
@fieldwise_init
struct Scalar(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, value: Int) -> Int: return value
def main(): _ = iterated(range(2)).filter_effect(Scalar())
