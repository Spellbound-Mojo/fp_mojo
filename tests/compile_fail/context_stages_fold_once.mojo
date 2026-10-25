# error: no matching method in call to 'fold_left'
from fp.functions import pipeline
from fp.callables import OnceBinary
@fieldwise_init
struct Step(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var a: Int, var b: Int) -> Int: return a + b
def main(): _ = pipeline(List[Int]([1, 2])).fold_left(Step(), 0).get()
