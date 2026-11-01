# error: if conforms_to(I, Parallel) else conforms_to(I, Parallel)'
from fp.functions import pipeline
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
    # pipeline[StateT] selects no Par: concurrent children cannot merge their states.
    _ = pipeline[L](element(1)).par_product_n((element(2),)).get()
