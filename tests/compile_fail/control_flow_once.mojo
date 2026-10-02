# error: no matching function
from fp.control import fori_loop
from fp.callables import OnceBinary
@fieldwise_init
struct Once(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var first: Int, var second: Int) -> Int:
        return 0

def main():
    _ = fori_loop(0, 3, Once(), 0)
