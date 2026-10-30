# error: lacking evidence to prove correctness
from fp.algebra import map
from fp.callables import OnceUnary
from fp.effects._async.engine import Async
@fieldwise_init
struct Keep[o: ImmOrigin](OnceUnary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Self.Arg
    def call_once(deinit self, var value: Self.Arg) -> Self.Out:
        return value
def wrong[o: ImmOrigin, p: ImmOrigin](var source: Async[Int].Pure[Span[Int, o]], var function: Keep[p]):
    _ = map[Async[Int]](source^, function^)
def main():
    pass
