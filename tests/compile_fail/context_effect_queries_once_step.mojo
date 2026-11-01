# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import OnceBinary
@fieldwise_init
struct Callback(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var a: Int, var b: Int) -> Self.Out: return Optional(a + b)
def main(): _ = pipeline(List[Int]([1,2])).fold_effect[OptionalFamily](0).run(Callback()).get()
