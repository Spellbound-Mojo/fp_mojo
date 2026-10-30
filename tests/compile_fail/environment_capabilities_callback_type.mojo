# error: constraint
from fp.effects import Reader, ask, local
from fp.callables import BorrowCallable
@fieldwise_init
struct Wrong(BorrowCallable, Defaultable):
    comptime Payload = Int
    comptime Result = String
    def invoke(self, ref value: Int) raises Never capturing -> String: return String(value)
def main(): _ = local[Reader[Int]](ask[Reader[Int]](), Wrong())
