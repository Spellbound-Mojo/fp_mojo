# error: no matching
from fp.effects.resources import resource
from fp.callables import OnceThunk, OnceUnary
@fieldwise_init
struct Acquire(OnceThunk):
    comptime Out = Int
    def call_once(deinit self) -> Int: return 1
@fieldwise_init
struct Release(OnceUnary):
    comptime Arg = String
    comptime Out = NoneType
    def call_once(deinit self, var value: String) -> NoneType: return None
def main():
    _ = resource[Error](Acquire(), Release())
