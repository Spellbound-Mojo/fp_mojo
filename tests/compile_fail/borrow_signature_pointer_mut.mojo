# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(mut value: Int) -> Bool: return True
comptime Callback = def(mut Int) thin -> Bool
def main():
    var pointer: Callback = bad
    _ = BorrowSignature[Int, Bool].capture(pointer)
