# error: use of uninitialized value
from fp.iteration import iterated
from fp.callables import BorrowSignature
def observe(value: Int) -> Optional[Int]: return Optional(value)
def main():
    var source = iterated(range(2))
    _ = source^.traverse_tap(BorrowSignature[Int,Optional[Int]].capture(observe))
    _ = source^.traverse_tap(BorrowSignature[Int,Optional[Int]].capture(observe))
