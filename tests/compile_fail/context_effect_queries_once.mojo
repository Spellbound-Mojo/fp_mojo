# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import OnceUnary
@fieldwise_init
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(Optional(value))
def main(): _ = pipeline(List[Int]([1,2])).find_map_effect[OptionalFamily](Callback()).get()
