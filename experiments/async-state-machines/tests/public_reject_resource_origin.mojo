from fp.data import Result, Ok
from fp.effects import EffectFailure, IOContext
# error: lacking evidence to prove correctness
from fp.callables import BorrowOnceCallable
from fp.effects.async_runtime import Resource, Pure, pure
from fp.effects.async_runtime.protocols import ScopedMachine, Step
@fieldwise_init
struct Release[o: ImmOrigin](ScopedMachine):
    comptime Input = Int
    comptime Value = NoneType
    comptime Error = Span[Int, Self.o]
    def poll[p: ImmOrigin](mut self, ref[p] value: Int, context: IOContext[Self.Error]) -> Step[NoneType, Self.Error]:
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Self.Error]](Ok(unit))))
@fieldwise_init
struct Body[o: ImmOrigin](BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Pure[Int, Span[Int, Self.o]]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return pure[Span[Int, Self.o]](value)
def wrong[o: ImmOrigin, p: ImmOrigin](var source: Resource[Pure[Int, Span[Int, o]], Release[o]], var body: Body[p]):
    _ = source^.use(body^)
def main():
    pass
