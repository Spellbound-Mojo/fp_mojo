# error: value passed to 'function' cannot be converted from 'def element(var index: Int) thin -> _StateLift[Async[Int], Int, IO[Int, Int]]
from fp.iteration import par_traverse
from fp.algebra import StringMonoid
from fp.effects import StateT
from fp.effects.async_runtime import IO, Async

comptime L = StateT[Async[Int], Int]


def element(var index: Int) -> L.Lifted[IO[Int, Int]]:
    return L.lift(IO[Int, Int].pure(index))


def indices() -> List[Int]:
    var values = List[Int]()
    values.append(1)
    return values^


def main():
    # Inferred from the callback's StateT carrier, which has no Parallel family.
    _ = par_traverse(indices(), element)
