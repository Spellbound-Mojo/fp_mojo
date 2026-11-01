# error: value passed to 'function' cannot be converted from 'def element(var index: Int) thin -> WriterValue[WriterT[Async[Int], StringMonoid]
from fp.iteration import par_traverse
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
    # Inferred from the callback's WriterT carrier, which has no Parallel family.
    _ = par_traverse(indices(), element)
