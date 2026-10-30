# error: no matching function in call to 'map'
from fp.callables import MutableUnary
from fp.iteration import iterated, map
struct Callback(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = String
    def __init__(out self): pass
    def call_mut(mut self, var value: Int) raises String -> Int: return value
def main(): _ = map(range(3), Callback())
