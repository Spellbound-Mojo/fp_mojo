# error: no matching
from fp.iteration import iterated
from fp.callables import Unary
@fieldwise_init
struct Consume(Unary):
    comptime Arg = Int
    comptime Out = Optional[Bool]
    def call(self, var value: Int) -> Self.Out: return Optional(value > 0)
def main(): _ = iterated(range(2)).filter_effect(Consume())
