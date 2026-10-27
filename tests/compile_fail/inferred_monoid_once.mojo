# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[String]
    def call_once(deinit self, var x: Int) -> Self.Out: return Optional(String(x))
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid](Once())
