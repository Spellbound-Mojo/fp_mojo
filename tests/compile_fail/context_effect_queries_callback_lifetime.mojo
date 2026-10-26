# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var count = String("owned")
    def callback(value: Int) {var count^} -> Reader[Int].Pure[Bool]: return Reader[Int].pure(value == count.byte_length())
    var pending = pipeline(List[Int]([1,2])).find_effect[Reader[Int]](callback).get()
    var moved = callback^
    _ = moved(0)
    _ = run[Reader[Int]](pending^, 0)
