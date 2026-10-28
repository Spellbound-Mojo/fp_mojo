# error: no matching function in call to 'filter_not'
from fp.callables import BorrowOnceCallable, BorrowCallContract, BorrowMutableCallable
from fp.functions import pipeline, piped
from fp.algebra import ListFamily, filter, filter_not
struct Invalid(BorrowMutableCallable, Movable):
    comptime Payload = String
    comptime Result = Bool
    def __init__(out self): pass
    def invoke_mut(mut self, ref value: String) -> Bool: return True

def main():
    var values: List[Int] = [0, 1]
    _ = filter_not[ListFamily](Invalid(), values^)
