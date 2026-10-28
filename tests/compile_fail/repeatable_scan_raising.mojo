# error: no matching method in call to 'scan_left'
from fp.callables import MutableBinary
from fp.iteration import iterated
struct Callback(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = String
    def __init__(out self): pass
    def call_mut(mut self, var first: Int, var second: Int) raises String -> Int: return first
def main(): _ = iterated(range(2)).scan_left(Callback(), 0)
