# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var owner = String("capture")
    def callback(value: Int) {var owner^} -> Int: return owner.byte_length() + value
    comptime Deferred = Reader[Int]
    var pending = pipeline[Deferred](Deferred.pure(1)).pair_with(callback).get()
    var moved = callback^
    _ = moved(0)
    _ = run[Deferred](pending^,0)
