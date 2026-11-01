# error: constraint
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
@fieldwise_init
struct Wrong(Unary):
    comptime Arg = String
    comptime Out = Optional[List[Int]]
    def call(self, var value: String) -> Self.Out: return None
def main(): _ = iterated(range(2)).flat_traverse(Wrong())
