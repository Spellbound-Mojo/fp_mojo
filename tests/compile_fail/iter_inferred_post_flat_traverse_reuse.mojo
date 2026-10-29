# error: use of uninitialized value
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
@fieldwise_init
struct Good(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    def call(self, var value: Int) -> Self.Out: return Optional(List[Int]([value]))
def main():
    var source = iterated(range(2))
    _ = source^.flat_traverse(Good())
    _ = source^.flat_traverse(Good())
