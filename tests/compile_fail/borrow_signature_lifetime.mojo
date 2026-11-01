# error: use of uninitialized value 'callback'
from fp.callables import BorrowSignature
from fp.iteration import iterated
def below(value: Int) -> Bool: return value < 3
def main() raises:
    var callback = BorrowSignature[Int, Bool].capture(below)
    var pending = iterated(range(4)).filter(callback)
    var extracted = callback^.into_function()
    _ = pending^.collect_list()
    _ = extracted(1)
