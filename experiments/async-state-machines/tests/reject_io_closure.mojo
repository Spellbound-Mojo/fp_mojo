# error: no matching method in call to 'flat_map'
from fp.functions import pipeline
from state_machine import IO
def main():
    var offset = 3
    def shift(value: Int) {offset} -> IO[Int, Int]:
        return IO[Int, Int].pure(value + offset)
    _ = pipeline(IO[Int, Int].pure(1)).flat_map(shift).get()
