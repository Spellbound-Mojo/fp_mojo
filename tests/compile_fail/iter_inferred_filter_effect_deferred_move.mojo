# error: uninitialized
from fp.iteration import iterated
from fp.effects import Reader, run
from fp.callables import BorrowSignature, shared_ref
def main():
    var capture = String("owned")
    def callback(value: Int) {var capture^} -> Reader[Int].Pure[Bool]: return Reader[Int].pure(capture.byte_length() > value)
    var predicate = BorrowSignature[Int,Reader[Int].Pure[Bool]].capture(callback^)
    var pending = iterated(range(3)).filter_effect(shared_ref(predicate))
    var moved = predicate^
    _ = moved.invoke(0)
    _ = run[Reader[Int]](pending^,0)
