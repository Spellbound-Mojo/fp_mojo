# error: expected 'conforms_to(I, Parallel) if
from fp.algebra import par_traverse
from fp.algebra import StringMonoid
from fp.effects import ReaderT
from fp.effects.async_runtime import IO, Async

comptime L = ReaderT[Async[Int], Int]


def element(var index: Int) -> L.Lifted[IO[Int, Int]]:
    return L.lift(IO[Int, Int].pure(index))


def indices() -> List[Int]:
    var values = List[Int]()
    values.append(1)
    return values^


def main():
    # ReaderT has no Parallel: the environment would have to live inside every child IO, the escape `reject_reader_environment_escape` rejects.
    _ = par_traverse[L](indices(), element)
