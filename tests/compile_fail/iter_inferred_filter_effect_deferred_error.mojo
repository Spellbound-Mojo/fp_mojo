# error: cannot call function that may raise
from fp.iteration import iterated
from fp.effects import Reader, run
from fp.callables import BorrowCallable
@fieldwise_init
struct Reject(BorrowCallable):
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[Bool]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result: raise value
def main():
    var pending = iterated(range(2)).filter_effect(Reject())
    _ = run[Reader[Int]](pending^,0)
