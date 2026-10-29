# error: cannot call function that may raise
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
@fieldwise_init
struct Raised(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out: raise value
def main(): _ = iterated(range(2)).traverse_filter(Raised())
