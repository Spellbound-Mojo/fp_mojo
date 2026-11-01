# error: no matching function in call to 'split'
from fp.functions import split
from fp.callables import UnaryContract
struct Missing(Movable, UnaryContract):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = split(Missing(), Missing())
