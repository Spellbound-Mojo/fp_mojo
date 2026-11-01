# error: alias
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x)
@fieldwise_init
struct Counter(MutableUnary):
    var count: Int
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        self.count += 1
        return Reader[Int].pure(arg + self.count)
def main():
    var chain = kleisli[Reader[Int]](source).then(Counter(0)).then(Counter(10))
    var first = chain.call_mut(1)
    var second = chain.call_mut(2)
    _ = (first^, second^)
