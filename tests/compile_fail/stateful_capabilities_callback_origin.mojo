# error: constraint
from fp.effects import State, ReaderT, LiftStateful, modify
from fp.callables import OnceUnary
@fieldwise_init
struct Update[o: ImmOrigin](OnceUnary, Defaultable):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out: return value
def bad(left: List[Int], right: List[Int]):
    comptime S = State[Span[Int, origin_of(left)]]
    _ = modify[LiftStateful[ReaderT[S, Int], S]](Update[origin_of(right)]())
def main(): bad([1], [2])
