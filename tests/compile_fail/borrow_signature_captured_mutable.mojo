# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def main():
    var limit = 3
    def bad(mut value: Int) {limit} -> Bool: return value < limit
    _ = BorrowSignature[Int, Bool].capture(bad)
