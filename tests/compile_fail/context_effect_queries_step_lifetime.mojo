# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var count = String("owned")
    def callback(var acc: Int, var value: Int) {var count^} -> Reader[Int].Pure[Int]: return Reader[Int].pure(acc + value + count.byte_length())
    var pending = pipeline(List[Int]([1,2])).fold_effect[Reader[Int]](0).run(callback).get()
    var moved = callback^
    _ = moved(0,0)
    _ = run[Reader[Int]](pending^, 0)
