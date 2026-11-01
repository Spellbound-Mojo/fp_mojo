# error: no matching method in call to 'filter_map'
from fp.callables import MutableUnary
from fp.iteration import iterated, filter_map
struct Callback(MutableUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    comptime Error = String
    def __init__(out self): pass
    def call_mut(mut self, var value: Int) raises String -> Optional[Int]: return Optional(value)
def main(): _ = iterated(range(3)).filter_map(Callback())
