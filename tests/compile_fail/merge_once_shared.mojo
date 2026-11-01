# error: pipeline: a shared call requires a reusable shared stage
from fp.functions import merge
from fp.callables import OnceUnary
struct Shift(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> Int: return value + 1
def main(): _ = merge(Shift(), Shift())(1)
