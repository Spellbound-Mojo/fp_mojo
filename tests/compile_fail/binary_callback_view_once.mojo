# error: no matching function
from fp.functions import flip
from fp.iteration import zip_with
from fp.callables import OnceBinary
@fieldwise_init
struct Once(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var first: Int, var second: Int) -> Int: return first + second
def main():
    var callback = flip(Once())
    _ = zip_with(callback^, range(2), range(2))
