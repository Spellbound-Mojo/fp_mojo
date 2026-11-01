# error: pipeline: a shared call requires a reusable shared stage
from fp.functions import untupled
from fp.callables import MutableUnary
struct Step(MutableUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    def __init__(out self): pass
    def call_mut(mut self, var pair: Self.Arg) -> Int: return pair[0]
def main(): _ = untupled(Step())(1, 2)
