# error: no matching function in call to 'filter_not'
from fp.callables import BorrowOnceCallable, BorrowCallContract, BorrowMutableCallable
from fp.functions import pipeline
from fp.algebra import ListFamily, filter, filter_not
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    def __init__(out self): pass
    def invoke_once(deinit self, ref value: Int) -> Bool: return True

def main():
    var values: List[Int] = [0, 1]
    _ = filter_not[ListFamily](values^, Once())
