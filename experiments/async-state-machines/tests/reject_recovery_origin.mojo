# error: lacking evidence to prove correctness
from fp.callables import OnceUnary
from fp.effects import EffectFailure
from fp.effects._async.family import Async
from fp.effects._async.recovery import handle_error_with
@fieldwise_init
struct Handler[o: ImmOrigin](OnceUnary):
    comptime Arg = EffectFailure[Span[Int, Self.o]]
    comptime Out = Async[Span[Int, Self.o]].Pure[Int]
    def call_once(deinit self, var error: Self.Arg) -> Self.Out:
        return Async[Span[Int, Self.o]].pure(1)
def wrong[o: ImmOrigin, p: ImmOrigin](var source: Async[Span[Int, o]].Pure[Int], var handler: Handler[p]):
    _ = handle_error_with(source^, handler^)
def main():
    pass
