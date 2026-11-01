# error: if conforms_to(I, Parallel) else conforms_to(I, Parallel)'
from fp.functions import pipeline
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
    # pipeline[WriterT] selects no Par: the log would be lost on failure and cancellation.
    _ = pipeline[L](element(1)).par_product_n((element(2),)).get()
