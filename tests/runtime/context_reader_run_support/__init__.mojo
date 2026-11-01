from fp.algebra import IdentityFamily, ListFamily, OptionalFamily, pure, traverse
from fp.callables import OnceUnary, MutableUnary, Unary
from fp.effects import Reader, ReaderT, ReaderAction, run
from std.testing import assert_equal

@fieldwise_init
struct FailRead(ReaderAction):
    comptime Family = Reader[Int]
    comptime Env = Int
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    comptime Error[o: ImmOrigin] = Pointer[Int, o]
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) raises Self.Error[o] -> Int:
        raise Pointer(to=env)

@fieldwise_init
struct Produce[o: ImmOrigin](MutableUnary):
    var failure: Pointer[Int, Self.o]
    comptime Arg = Int
    comptime Out = FailRead
    comptime Error = Pointer[Int, Self.o]
    def call_mut(mut self, var value: Int) raises Self.Error -> Self.Out:
        if value < 0:
            raise self.failure
        return FailRead()

@fieldwise_init
struct Once(OnceUnary):
    comptime I = Reader[Int]
    comptime Arg = Int
    comptime Out = Self.I.Pure[Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return pure[Self.I](value)

@fieldwise_init
struct Length(Unary):
    comptime Arg = List[Int]
    comptime Out = Int
    def call(self, var values: List[Int]) -> Int:
        return len(values)

@fieldwise_init
struct Continue(Unary):
    comptime I = Reader[Int]
    comptime Arg = List[Int]
    comptime Out = Self.I.Pure[Int]
    def call(self, var values: List[Int]) -> Self.Out:
        return pure[Self.I](len(values))
