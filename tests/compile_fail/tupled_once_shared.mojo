# error: tupled: a shared call requires a Binary
from fp.functions import tupled
from fp.callables import OnceBinary
struct Add(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var first: Int, var second: Int) -> Int: return first + second
def main(): _ = tupled(Add())((1, 2))
