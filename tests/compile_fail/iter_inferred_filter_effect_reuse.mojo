# error: use of uninitialized value
from fp.iteration import iterated
from fp.callables import BorrowSignature
def observe(value: Int) -> Optional[Bool]: return Optional(value > 0)
def main():
    var source = iterated(range(2))
    _ = source^.filter_effect(BorrowSignature[Int,Optional[Bool]].capture(observe))
    _ = source^.filter_effect(BorrowSignature[Int,Optional[Bool]].capture(observe))
