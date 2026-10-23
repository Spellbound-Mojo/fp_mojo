# error: constraint
from fp.data import Result, Ok
from fp.callables import OnceUnary
@fieldwise_init
struct RORejectedRaised[E: Movable & Deinitable](OnceUnary):
    var error: Self.E
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Self.E
    def call_once(deinit self, var value: Int) raises Self.Error -> Int: raise self.error^
def mismatch(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    try: _ = Result[Int, Int](Ok(1)).map_both(RORejectedRaised[type_of(a)](a), RORejectedRaised[type_of(b)](b))
    except error: pass
def main(): mismatch([1], [2])
