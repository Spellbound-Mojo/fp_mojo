# error: no matching function in call to 'filter_map'
from fp.callables import OnceUnary
from fp.iteration import iterated, filter_map
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> Optional[Int]: return Optional(value)
def main(): _ = filter_map(Callback(), range(3))
