# error: lacking evidence to prove correctness
from fp.callables import BorrowOnceCallable
from fp.effects import IOContext
from fp.effects._async.resources import Resource
from fp.effects._async.composition import Pure, pure
from fp.effects._async.scopes import ScopedMachine
from fp.effects._async.kernel import Step
@fieldwise_init
struct Release[o: ImmOrigin](ScopedMachine):
    comptime Input = Int
    comptime Value = NoneType
    comptime Error = Span[Int, Self.o]
    def poll[p: ImmOrigin](mut self, ref[p] value: Int, context: IOContext[Self.Error]) -> Step[NoneType, Self.Error]:
        var unit: NoneType = None
        var done = pure[Self.Error](unit)
        return done.poll(context)
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
