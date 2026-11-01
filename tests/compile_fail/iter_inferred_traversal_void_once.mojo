# error: no matching
from fp.iteration import iterated
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(value)
def main():
    _ = iterated(List[Int]([1])).traverse_void(Once())
