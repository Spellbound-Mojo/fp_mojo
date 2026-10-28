# error: no matching function in call to 'untupled'
from fp.functions import untupled
from fp.callables import UnaryContract
struct Missing(Movable, UnaryContract):
    comptime Arg = Tuple[Int,Int]
    comptime Out = Int
    def __init__(out self): pass

def main(): _ = untupled(Missing())
