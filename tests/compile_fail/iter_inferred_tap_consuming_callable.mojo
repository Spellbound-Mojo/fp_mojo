# error: no matching
from fp.iteration import iterated
from fp.callables import Unary
@fieldwise_init
struct Consume(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Self.Out: return Optional(value)
def main(): _ = iterated(range(2)).traverse_tap(Consume())
