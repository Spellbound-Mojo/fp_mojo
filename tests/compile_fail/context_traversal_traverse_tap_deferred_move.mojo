# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var capture = String("owned")
    comptime Deferred = Reader[Int]
    def callback(value: Int) {var capture^} -> Deferred.Pure[Bool]: return Deferred.pure(capture.byte_length() > value)
    var pending = pipeline(List[Int]([1])).traverse_tap[Deferred](callback).get()
    var moved = callback^
    _ = moved(0)
    _ = run[Deferred](pending^,0)
