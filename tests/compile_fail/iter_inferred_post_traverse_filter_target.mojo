# error: constraint
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
@fieldwise_init
struct Good(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call(self, var value: Int) -> Self.Out: return Optional(Optional(value))
def main(): _ = iterated(range(2)).traverse_filter[ResultFamily[String]](Good())
