# error: constraint
from fp.data import Result, Ok
from fp.callables import OnceUnary
@fieldwise_init
struct RORejectedMap[T: Movable & Deinitable](OnceUnary):
    var view: Self.T
    comptime Arg = Int
    comptime Out = Self.T
    def call_once(deinit self, var value: Int) -> Self.T: return self.view^
def mismatch(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    _ = Result[Int, Int](Ok(1)).redeem(RORejectedMap[type_of(a)](a), RORejectedMap[type_of(b)](b))
def main(): mismatch([1], [2])
