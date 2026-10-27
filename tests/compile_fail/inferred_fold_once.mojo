# error: no matching
from fp.functions import pipeline
from fp.callables import OnceBinary
@fieldwise_init
struct Once(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var first: Int, var second: Int) -> Self.Out: return Optional(first + second)
def main():
    _ = pipeline(List[Int]([1])).fold_effect(0).run(Once())
