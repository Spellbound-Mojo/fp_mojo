# error: uninitialized
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result
from fp.effects import Reader, run
def main():
    var owner = String("capture")
    def transform(var value: Int) {var owner^} -> Int:
        return value + owner.byte_length()
    comptime Family = Reader[Int]
    var pending = piped[Family](Family.pure(1)).map(transform).get()
    var moved = transform^
    _ = moved(0)
    _ = run[Family](pending^, 0)
