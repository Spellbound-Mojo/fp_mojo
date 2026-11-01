# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var capture = String("owned")
    def callback(var value: Int) {var capture^} -> Reader[Int].Pure[Optional[Int]]:
        return Reader[Int].pure(Optional(value + capture.byte_length()))
    var pending = pipeline(List[Int]([1])).traverse_filter[Reader[Int]](callback).get()
    var moved = callback^
    _ = moved(0)
    _ = run[Reader[Int]](pending^,0)
