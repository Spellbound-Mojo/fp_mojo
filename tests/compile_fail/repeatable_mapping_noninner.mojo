# error: IterableOwned
from fp.callables import MutableUnary
from fp.iteration import iterated
struct Wrong(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_mut(mut self, var value: Int) -> Int: return value
def main(): _ = iterated(range(2)).flat_map(Wrong())
