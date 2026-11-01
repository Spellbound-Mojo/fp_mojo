from fp.effects import State, StateAction
from fp.algebra import pure
from fp.callables import MutableUnary, OnceUnary, Unary, Binary

@fieldwise_init
struct Fail[o: ImmOrigin](StateAction):
    var failure: Pointer[Int, Self.o]
    comptime Family = State[Int]
    comptime State = Int
    comptime Value = Int
    comptime Out = Tuple[Int, Int]
    comptime Error = Pointer[Int, Self.o]
    def run(deinit self, var state: Int) raises Self.Error -> Self.Out:
        raise self.failure

@fieldwise_init
struct Produce[a: ImmOrigin, b: ImmOrigin](MutableUnary):
    var first: Pointer[Int, Self.a]
    var second: Pointer[Int, Self.b]
    comptime Arg = Int
    comptime Out = Fail[Self.b]
    comptime Error = Pointer[Int, Self.a]
    def call_mut(mut self, var value: Int) raises Self.Error -> Self.Out:
        if value < 0:
            raise self.first
        return Fail[Self.b](self.second)

@fieldwise_init
struct Once(OnceUnary):
    comptime I = State[Int]
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
    comptime I = State[Int]
    comptime Arg = List[Int]
    comptime Out = Self.I.Pure[Int]
    def call(self, var values: List[Int]) -> Self.Out:
        return pure[Self.I](len(values))


@fieldwise_init
struct LengthPlus(Binary):
    comptime First = List[Int]
    comptime Second = Int
    comptime Out = Int
    def call(self, var values: List[Int], var amount: Int) -> Int:
        return len(values) + amount
