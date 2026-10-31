# error: uninitialized
from fp.functions import pipeline
from fp.algebra import pure
from fp.effects import Reader, run
def main():
    var owner = String('capture')
    def make() {var owner^} -> Reader[Int].Pure[Int]:
        return pure[Reader[Int]](owner.byte_length())
    var pending = pipeline[Reader[Int]](pure[Reader[Int]](1)).before(make).get()
    var moved = make^
    _ = moved()
    _ = run[Reader[Int]](pending^,0)
