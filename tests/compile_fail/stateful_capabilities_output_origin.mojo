# error: constraint
from fp.effects import State, ReaderT, LiftStateful, modify
from fp.callables import OnceUnary
@fieldwise_init
struct Update[a: ImmOrigin, b: ImmOrigin](OnceUnary):
    var replacement: Span[Int, Self.b]
    comptime Arg = Span[Int, Self.a]
    comptime Out = Span[Int, Self.b]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out: return self.replacement
def bad(left: List[Int], right: List[Int]):
    comptime S = State[Span[Int, origin_of(left)]]
    _ = modify[LiftStateful[ReaderT[S, Int], S]](Update[origin_of(left), origin_of(right)](Span(right)))
def main(): bad([1], [2])
