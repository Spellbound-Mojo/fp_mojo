# error: constraint
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(List[Int]([value]))
def main(): _ = iterated(range(2)).flat_traverse(Once())
