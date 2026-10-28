# error: no matching method in call to 'flat_map'
from fp.callables import OnceUnary
from fp.iteration import iterated, flat_map
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = List[Int]
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> List[Int]: return [value]
def main(): _ = iterated(range(3)).flat_map(Callback())
