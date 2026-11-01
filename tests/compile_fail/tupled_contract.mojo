# error: no matching function in call to 'tupled'
from fp.functions import tupled
from fp.callables import BinaryContract
struct Missing(Movable, BinaryContract):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = tupled(Missing())
