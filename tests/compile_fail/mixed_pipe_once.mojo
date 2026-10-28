# error: no matching function
from fp.functions import pipe
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value
def native(var value: Int) -> Int: return value + 1
def main(): _ = pipe(3, native, Once())
