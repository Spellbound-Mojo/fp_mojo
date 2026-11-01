# error: no matching
from fp.functions import pipeline
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(value)
def main():
    _ = pipeline(List[Int]([1])).traverse(Once())
