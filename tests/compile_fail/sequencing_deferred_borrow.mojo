# error: uninitialized
from fp.functions import piped
from fp.algebra import pure
from fp.effects import Reader, run
def main():
    var owner = String('capture')
    def make() {var owner^} -> Reader[Int].Pure[Int]:
        return pure[Reader[Int]](owner.byte_length())
    var pending = piped(pure[Reader[Int]](1)).before[Reader[Int]](make).get()
    var moved = make^
    _ = moved()
    _ = run[Reader[Int]](pending^,0)
