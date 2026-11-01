# error: use of uninitialized value 'callback'
from fp.callables import BorrowSignature
def below(value: Int) -> Bool: return value < 3
def main():
    var callback = BorrowSignature[Int, Bool].capture(below)
    var extracted = callback^.into_function()
    var value = 1
    _ = callback.invoke(value)
    _ = extracted(value)
