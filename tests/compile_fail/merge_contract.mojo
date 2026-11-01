# error: no matching function in call to 'merge'
from fp.functions import merge
from fp.callables import UnaryContract
struct Missing(Movable, UnaryContract):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = merge(Missing(), Missing())
