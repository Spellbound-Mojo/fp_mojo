# error: no matching function in call to 'map'
from fp.data import NonEmptyList
from fp.algebra import NonEmptyListFamily, map
from fp.callables import OnceUnary
@fieldwise_init
struct NELOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg
def main():
    _ = map[NonEmptyListFamily](NELOnce(), NonEmptyList(1))
