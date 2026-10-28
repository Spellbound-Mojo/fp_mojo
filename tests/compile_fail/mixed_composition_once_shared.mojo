# error: constraint failed: pipeline: a shared call requires a reusable shared stage
from fp.functions import flow
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value
def native(var value: Int) -> Int: return value + 1
def main():
    var chain = flow(native, Once())
    _ = chain(3)
