# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(mut value: Int) -> Bool: return value < 4
def main(): _ = BorrowSignature[Int, Bool].capture(bad)
