# error: lacking evidence to prove correctness
from fp.callables import OnceUnary
from fp.effects import EffectFailure
from fp.effects._async.engine import IO
@fieldwise_init
struct Handler[o: ImmOrigin](OnceUnary):
    comptime Arg = EffectFailure[Span[Int, Self.o]]
    comptime Out = IO[Int, Span[Int, Self.o]]
    def call_once(deinit self, var error: Self.Arg) -> Self.Out:
        return Self.Out.pure(1)
def wrong[o: ImmOrigin, p: ImmOrigin](var source: IO[Int, Span[Int, o]], var handler: Handler[p]):
    _ = source^.handle_error_with(handler^)
def main():
    pass
