# error: no matching method in call to 'map'
from fp.callables import MutableUnary
from fp.iteration import iterated
struct Wrong(MutableUnary):
    comptime Arg = String
    comptime Out = Int
    def __init__(out self): pass
    def call_mut(mut self, var value: String) -> Int: return value.byte_length()
def main(): _ = iterated(range(2)).map(Wrong())
