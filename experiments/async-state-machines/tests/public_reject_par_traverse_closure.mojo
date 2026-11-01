# error: no matching function in call to 'par_traverse'
from fp.algebra import par_traverse
from fp.effects.async_runtime import IO


def main():
    var offset = 3
    def shifted(var value: Int) {offset} -> IO[Int, Int]:
        return IO[Int, Int].pure(value + offset)

    var values = List[Int]()
    values.append(1)
    # IO keeps its callbacks until it runs, so a borrowed closure is rejected.
    _ = par_traverse(values^, shifted)
