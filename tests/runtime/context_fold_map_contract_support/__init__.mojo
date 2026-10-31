from fp.algebra import FoldMapContract, Monad, Monoid, IdentityFamily, pure
from fp.callables import UnaryContract, Unary, MutableUnary, OnceUnary
from fp.effects import Reader
from fp.iteration import fold_map_effect, Iter
from std.iter import Iterator
from fp.functions import piped, pipeline, Pipeline
from std.memory import ArcPointer


def forward[I: Monad, M: Monoid, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FoldMapContract[I, M, V, F].Error -> FoldMapContract[I, M, V, F].Out where FoldMapContract[I, M, V, F].Compatible:
    return fold_map_effect[M, I](source^, function^)


def fluent[I: Monad, M: Monoid, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FoldMapContract[I, M, V, F].Error -> FoldMapContract[I, M, V, F].Out where FoldMapContract[I, M, V, F].Compatible:
    return piped(source^).fold_map_effect[M, I](function^).get()


def iterator_forward[I: Monad, M: Monoid, V: Iterator, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: Iter[V]
) raises FoldMapContract[I, M, V, F].Error -> FoldMapContract[I, M, V, F].Out where FoldMapContract[I, M, V, F].Compatible:
    return source^.fold_map_effect[I, M](function^)


def selected[I: Monad, M: Monoid, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FoldMapContract[I, M, V, F].Error -> Pipeline[I, FoldMapContract[I, M, V, F].Out] where FoldMapContract[I, M, V, F].Compatible:
    return pipeline[IdentityFamily](source^).fold_map_effect[I, M](function^)


@fieldwise_init
struct Text[I: Monad](Unary):
    comptime Arg = Int
    comptime Out = Self.I.Pure[String]
    def call(self, var value: Int) -> Self.Out:
        return pure[Self.I](String(value))


@fieldwise_init
struct Owned(Movable):
    var value: Int


struct OwnedSum(Monoid):
    comptime Value = Owned
    @staticmethod
    def empty() -> Owned:
        return Owned(0)
    @staticmethod
    def combine(var first: Owned, var second: Owned) -> Owned:
        return Owned(first.value + second.value)


@fieldwise_init
struct ProduceOwned[I: Monad](Unary):
    comptime Arg = Int
    comptime Out = Self.I.Pure[Owned]
    def call(self, var value: Int) -> Self.Out:
        return pure[Self.I](Owned(value))


@fieldwise_init
struct ProduceSource[I: Monad](Unary):
    comptime Arg = Owned
    comptime Out = Self.I.Pure[String]
    def call(self, var value: Owned) -> Self.Out:
        return pure[Self.I](String(value.value))


@fieldwise_init
struct OnceText(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[String]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return Optional(String(value))


@fieldwise_init
struct CountingText(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Optional[String]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls += 1
        return Optional(String(value) + ":" + String(self.calls) + ";")


@fieldwise_init
struct Branches(Unary):
    comptime Arg = Int
    comptime Out = List[String]
    def call(self, var value: Int) -> Self.Out:
        return [String(value) + "a", String(value) + "b"]


@fieldwise_init
struct Borrowed[I: Monad, v: ImmOrigin, e: ImmOrigin](Unary):
    var value: Pointer[Int, Self.v]
    var failure: Pointer[Int, Self.e]
    comptime Arg = Int
    comptime Out = Self.I.Pure[List[Pointer[Int, Self.v]]]
    comptime Error = Pointer[Int, Self.e]
    def call(self, var value: Int) raises Self.Error -> Self.Out:
        if value < 0:
            raise self.failure
        var values = List[Pointer[Int, Self.v]]()
        values.append(self.value)
        return pure[Self.I](values^)


struct FallibleMonoid[initial_fails: Bool](Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String:
        if Self.initial_fails:
            raise 71
        return ""
    @staticmethod
    def combine(var first: String, var second: String) raises Int -> String:
        if second == "bad":
            raise 73
        return first + second


@fieldwise_init
struct Later(Unary):
    var calls: ArcPointer[Int]
    var bad_at: Int
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[String]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value < 0:
            raise 72
        return pure[Reader[Int]](String("bad") if value == self.bad_at else String(value))


@fieldwise_init
struct IncompatibleError(Unary):
    comptime Arg = Int
    comptime Out = Optional[String]
    comptime Error = String
    def call(self, var value: Int) raises String -> Self.Out:
        raise String(value)
