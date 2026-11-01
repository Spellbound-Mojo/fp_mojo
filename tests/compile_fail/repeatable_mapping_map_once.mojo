# error: no matching method in call to 'map'
from fp.callables import OnceUnary
from fp.iteration import iterated, map
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> Int: return value
def main(): _ = iterated(range(3)).map(Callback())
