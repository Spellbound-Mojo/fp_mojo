# error: no matching function
from fp.functions import pipe
from fp.callables import MutableUnary
@fieldwise_init
struct Mutable(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int: return value
def native(var value: Int) -> Int: return value + 1
def main(): _ = pipe(3, Mutable(), native)
