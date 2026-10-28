# error: use of uninitialized value 'chain'
from fp.functions import compose
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value
def native(var value: Int) -> Int: return value + 1
def main():
    var chain = compose(native, Once())
    _ = chain^.call_once(1)
    _ = chain^.call_once(2)
