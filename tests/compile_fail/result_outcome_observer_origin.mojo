# error: constraint
from fp.data import Result, Ok, Err
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct RORejectedObserver[A: Movable & Deinitable, B: Movable & Deinitable](BorrowOnceCallable):
    var error: Self.B
    comptime Payload = Result[Int, Self.A]
    comptime Result = Result[Int, Self.B]
    def invoke_once(deinit self, ref value: Self.Payload) raises Never capturing -> Self.Result:
        return Err(self.error^)
def mismatch(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    _ = Result[Int, type_of(a)](Ok(1)).attempt_tap(RORejectedObserver[type_of(a), type_of(b)](b))
def main(): mismatch([1], [2])
