# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: String) -> Bool: return True
def main():
    var pointer: def(String) thin -> Bool = bad
    _ = BorrowSignature[Int, Bool].capture(pointer)
