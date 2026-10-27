from fp.algebra import Monad, pure
from fp.callables import Binary, OnceBinary

@fieldwise_init
struct Owned(Movable):
    var value: Int

@fieldwise_init
struct SumOwned[I: Monad](Binary):
    comptime First = Int
    comptime Second = Owned
    comptime Out = Self.I.Pure[Int]
    def call(self, var first: Int, var second: Owned) -> Self.Out:
        return pure[Self.I](first + second.value)

@fieldwise_init
struct Add[I: Monad](Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.I.Pure[Int]
    def call(self, var first: Int, var second: Int) -> Self.Out:
        return pure[Self.I](first + second)

@fieldwise_init
struct Once[I: Monad](OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.I.Pure[Int]
    def call_once(deinit self, var first: Int, var second: Int) -> Self.Out:
        return pure[Self.I](first + second)

@fieldwise_init
struct Fallible[I: Monad, o: ImmOrigin](Binary):
    var failure: Pointer[Int, Self.o]
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.I.Pure[Int]
    comptime Error = Pointer[Int, Self.o]
    def call(self, var first: Int, var second: Int) raises Self.Error -> Self.Out:
        if second < 0:
            raise self.failure
        return pure[Self.I](first + second)


def owned_items() -> List[Owned]:
    var values = List[Owned]()
    values.append(Owned(1))
    values.append(Owned(2))
    return values^
