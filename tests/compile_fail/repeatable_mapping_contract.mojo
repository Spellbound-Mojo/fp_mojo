# error: no matching method in call to 'map'
from fp.callables import UnaryContract
from fp.iteration import iterated
struct Missing(Movable, UnaryContract):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
def main(): _ = iterated(range(2)).map(Missing())
