# error: no matching method in call to 'filter'
from fp.callables import BorrowOnceCallable, BorrowCallContract, BorrowMutableCallable
from fp.functions import pipeline, piped
from fp.algebra import ListFamily, filter, filter_not
struct Invalid(BorrowCallContract, Movable):
    comptime Payload = Int
    comptime Result = Bool
    def __init__(out self): pass

def main():
    var values: List[Int] = [0, 1]
    _ = pipeline(values^).filter(Invalid()).get()
