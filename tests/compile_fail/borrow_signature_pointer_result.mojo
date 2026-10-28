# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: Int) -> String: return "bad"
comptime Callback = def(Int) thin -> String
def main():
    var pointer: Callback = bad
    _ = BorrowSignature[Int, Bool].capture(pointer)
