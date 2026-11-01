# error: matching
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily
from fp.callables import MutableUnary
@fieldwise_init
struct Counter(MutableUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_mut(mut self, var arg: Int) -> Self.Out: return Optional(arg)
def main():
    var chain = kleisli[OptionalFamily](Counter())
    _ = iterated(range(3)).map(chain)
