# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: Int) raises Int: raise value
def main(): _ = BorrowSignature[Int, type_of(None)].capture(bad)
