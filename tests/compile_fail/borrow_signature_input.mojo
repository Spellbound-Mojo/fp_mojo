# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: Int) -> Bool: return True
def main(): _ = BorrowSignature[String, Bool].capture(bad)
