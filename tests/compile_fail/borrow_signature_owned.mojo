# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(var value: String) -> Bool: return True
def main(): _ = BorrowSignature[String, Bool].capture(bad)
