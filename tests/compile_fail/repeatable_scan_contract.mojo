# error: no matching method in call to 'scan_left'
from fp.callables import BinaryContract
from fp.iteration import iterated
struct Callback(Movable, BinaryContract):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = iterated(range(2)).scan_left(Callback(), 0)
