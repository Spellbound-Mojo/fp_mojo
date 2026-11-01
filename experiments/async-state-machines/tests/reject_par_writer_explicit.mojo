# error: expected 'conforms_to(I, Parallel) if
from fp.algebra import par_traverse
from fp.algebra import StringMonoid
from fp.effects import WriterT
from fp.effects.async_runtime import IO, Async

comptime L = WriterT[Async[Int], StringMonoid]


def element(var index: Int) -> L.Lifted[IO[Int, Int]]:
    return L.lift(IO[Int, Int].pure(index))


def indices() -> List[Int]:
    var values = List[Int]()
    values.append(1)
    return values^


def main():
    # WriterT has no Parallel: the log would be lost on failure and cancellation.
    _ = par_traverse[L](indices(), element)
