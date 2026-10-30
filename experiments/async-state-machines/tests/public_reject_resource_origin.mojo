# error: lacking evidence to prove correctness
from fp.callables import BorrowOnceCallable
from fp.effects.async_runtime import IO, Resource
@fieldwise_init
struct Body[o: ImmOrigin](BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = IO[Int, Span[Int, Self.o]]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return Self.Result.pure(value)
def wrong[o: ImmOrigin, p: ImmOrigin](var source: Resource[Int, Span[Int, o]], var body: Body[p]):
    _ = source^.use(body^)
def main():
    pass
