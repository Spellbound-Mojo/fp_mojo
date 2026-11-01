# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def main(): _ = BorrowSignature[Int, Bool].capture(3)
