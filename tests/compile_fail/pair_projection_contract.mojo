# error: no matching function in call to 'first'
from fp.functions import first
from fp.callables import UnaryContract
struct Missing(Movable, UnaryContract):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = first[String](Missing())
