# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(mut value: Int): pass
def main(): _ = BorrowSignature[Int, type_of(None)].capture(bad)
