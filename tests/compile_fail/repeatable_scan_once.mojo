# error: no matching method in call to 'scan_left'
from fp.callables import OnceBinary
from fp.iteration import iterated
struct Callback(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var first: Int, var second: Int) -> Int: return first
def main(): _ = iterated(range(2)).scan_left(Callback(), 0)
