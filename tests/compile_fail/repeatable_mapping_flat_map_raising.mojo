# error: no matching function in call to 'flat_map'
from fp.callables import MutableUnary
from fp.iteration import iterated, flat_map
struct Callback(MutableUnary):
    comptime Arg = Int
    comptime Out = List[Int]
    comptime Error = String
    def __init__(out self): pass
    def call_mut(mut self, var value: Int) raises String -> List[Int]: return [value]
def main(): _ = flat_map(Callback(), range(3))
