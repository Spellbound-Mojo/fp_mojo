# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: Int) raises Int -> Bool: raise value
def main(): _ = BorrowSignature[Int, Bool].capture(bad)
