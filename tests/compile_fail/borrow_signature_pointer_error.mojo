# error: no matching function in call to 'capture'
from fp.callables import BorrowSignature
def bad(value: Int) raises String -> Bool: raise String("bad")
def main():
    var pointer: def(Int) raises String thin -> Bool = bad
    _ = BorrowSignature[Int, Bool, Int].capture(pointer)
