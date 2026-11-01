# error: no matching
from fp.functions import pipeline
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var x: Int) -> Self.Out: return Optional(x)
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(Once())
