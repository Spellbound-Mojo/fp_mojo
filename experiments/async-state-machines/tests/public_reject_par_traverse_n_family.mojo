# error: no matching function in call to 'par_traverse_n'
from fp.algebra import par_traverse_n, Parallel
from fp.effects.async_runtime import IO, Async
from fp.callables import Unary


struct SequentialPar(Parallel):
    """A Parallel family whose Par, the sequential Async, has no limited loop."""
    comptime Par = Async[Int]


@fieldwise_init
struct Lift(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value)


def main():
    var values = List[Int]()
    values.append(1)
    _ = par_traverse_n[SequentialPar](2, values^, Lift())
