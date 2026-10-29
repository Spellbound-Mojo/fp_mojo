# error: cannot call function that may raise
from fp.iteration import iterated
from fp.callables import BorrowCallable
@fieldwise_init
struct Raises(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result: raise 7
def wrong() -> Optional[List[Int]]: return iterated(range(2)).traverse_tap(Raises())
def main(): _ = wrong()
