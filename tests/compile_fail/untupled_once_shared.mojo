# error: pipeline: a shared call requires a reusable shared stage
from fp.functions import untupled
from fp.callables import OnceUnary
struct Consume(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var pair: Self.Arg) -> Int: return pair[0]
def main(): _ = untupled(Consume())(1, 2)
