# error: use of uninitialized value 'callback'
from fp.callables import BorrowSignature
def below(value: Int) -> Bool: return value < 3
def main():
    var pointer: def(Int) thin -> Bool = below
    var callback = BorrowSignature[Int, Bool].capture(pointer)
    ref stored = callback.function()
    var extracted = callback^.into_function()
    _ = stored(1)
    _ = extracted(2)
