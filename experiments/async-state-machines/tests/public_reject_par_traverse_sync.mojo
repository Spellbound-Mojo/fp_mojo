# error: 'par_traverse' parameter 'I' has 'Functor' type, but value has type 'AnyStruct[SyncIO[Int]]'
from fp.algebra import par_traverse
from fp.effects import SyncIO, IO, delay
from fp.callables import Unary


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
    # SyncIO is a capability dictionary, not a Functor, and has no Parallel: nothing runs concurrently.
    _ = par_traverse[SyncIO[Int]](values^, Lift())
