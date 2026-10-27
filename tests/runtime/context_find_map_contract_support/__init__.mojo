from fp.algebra import FindMapContract, Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.callables import UnaryContract, Unary, MutableUnary, OnceUnary
from fp.effects import Reader, run
from std.memory import ArcPointer
from fp.iteration import find_map_effect, iterated, Iter
from std.iter import Iterator
from fp.functions import piped, pipeline, Pipeline
from std.testing import assert_equal
from algebra_support.box import BoxMonad

def forward[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FindMapContract[I, V, F].Error -> FindMapContract[I, V, F].Out where FindMapContract[I, V, F].Compatible:
    return find_map_effect[I](function^, source^)

def fluent[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FindMapContract[I, V, F].Error -> FindMapContract[I, V, F].Out where FindMapContract[I, V, F].Compatible:
    return piped(source^).find_map_effect[I](function^).get()

def iterator_forward[I: Monad, V: Iterator, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: Iter[V]
) raises FindMapContract[I, V, F].Error -> FindMapContract[I, V, F].Out where FindMapContract[I, V, F].Compatible:
    return source^.find_map_effect[I](function^)

def selected[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises FindMapContract[I, V, F].Error -> Pipeline[I, FindMapContract[I, V, F].Out] where FindMapContract[I, V, F].Compatible:
    return pipeline[IdentityFamily](source^).find_map_effect[I](function^)

@fieldwise_init
struct Text[I: Monad](Unary):
    comptime Arg = Int
    comptime Out = Self.I.Pure[Optional[String]]
    def call(self, var value: Int) -> Self.Out:
        return pure[Self.I](Optional(String(value)) if value == 2 else Optional[String]())

@fieldwise_init
struct Owned(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct OwnedQuery[I: Monad](MutableUnary):
    var capture: Owned
    var calls: ArcPointer[Int]
    comptime Arg = Owned
    comptime Out = Self.I.Pure[Optional[Owned]]
    def call_mut(mut self, var value: Owned) -> Self.Out:
        self.calls[] += 1
        return pure[Self.I](Optional(value^) if value.id == 2 else Optional[Owned]())

@fieldwise_init
struct OnceText(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Optional[String]]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return Optional(Optional(String(value)))

@fieldwise_init
struct Branches(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = List[Optional[String]]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls[] += 1
        return [Optional(String(value)), Optional[String]()]

@fieldwise_init
struct Borrowed[I: Monad, v: ImmOrigin, e: ImmOrigin](Unary):
    var failure: Pointer[Int, Self.e]
    comptime Arg = Pointer[Int, Self.v]
    comptime Out = Self.I.Pure[Optional[Pointer[Int, Self.v]]]
    comptime Error = Pointer[Int, Self.e]
    def call(self, var value: Self.Arg) raises Self.Error -> Self.Out:
        if value[] < 0:
            raise self.failure
        return pure[Self.I](Optional(value))

@fieldwise_init
struct Later(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Optional[String]]
    comptime Error = Int
    def call_mut(mut self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value < 0:
            raise value
        return pure[Reader[Int]](Optional(String(value)) if value == 2 else Optional[String]())


@fieldwise_init
struct WrongPayload(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[String]]
    def call(self, var value: Int) -> Self.Out:
        return Optional(List[String]([String(value)]))
