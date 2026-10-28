# error: pair mapping: a shared call requires a Unary
from fp.functions import first
from fp.callables import OnceUnary
struct Shift(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> Int: return value + 1
def main(): _ = first[String](Shift())((1, String("id")))
