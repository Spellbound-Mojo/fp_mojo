# error: no matching method in call to 'filter_not'
from fp.callables import BorrowOnceCallable, BorrowCallContract, BorrowMutableCallable
from fp.functions import pipeline
from fp.algebra import ListFamily, filter, filter_not
struct Invalid(BorrowMutableCallable, Movable):
    comptime Payload = Int
    comptime Result = Int
    def __init__(out self): pass
    def invoke_mut(mut self, ref value: Int) -> Int: return value

def main():
    var values: List[Int] = [0, 1]
    _ = pipeline(values^).filter_not(Invalid()).get()
