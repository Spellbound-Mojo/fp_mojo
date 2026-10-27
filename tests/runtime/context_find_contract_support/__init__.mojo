from fp.algebra import FindContract, Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.callables import BorrowCallable, BorrowOnceCallable
from fp.effects import Reader, run
from std.memory import ArcPointer
from context_find_map_contract_support import Owned
from fp.iteration import find_effect, iterated, Iter
from std.iter import Iterator
from fp.functions import piped, pipeline, Pipeline
from std.testing import assert_equal
from algebra_support.box import BoxMonad

def forward[I: Monad, V: Movable & Deinitable, C: BorrowCallable](
    var predicate: C, var source: V
) raises FindContract[I, V, C].Error -> FindContract[I, V, C].Out where FindContract[I, V, C].Compatible:
    return find_effect[I](predicate^, source^)

def fluent[I: Monad, V: Movable & Deinitable, C: BorrowCallable](
    var predicate: C, var source: V
) raises FindContract[I, V, C].Error -> FindContract[I, V, C].Out where FindContract[I, V, C].Compatible:
    return piped(source^).find_effect[I](predicate^).get()

def iterator_forward[I: Monad, V: Iterator, C: BorrowCallable](
    var predicate: C, var source: Iter[V]
) raises FindContract[I, V, C].Error -> FindContract[I, V, C].Out where FindContract[I, V, C].Compatible:
    return source^.find_effect[I](predicate^)

def selected[I: Monad, V: Movable & Deinitable, C: BorrowCallable](
    var predicate: C, var source: V
) raises FindContract[I, V, C].Error -> Pipeline[I, FindContract[I, V, C].Out] where FindContract[I, V, C].Compatible:
    return pipeline[IdentityFamily](source^).find_effect[I](predicate^)

@fieldwise_init
struct Even[I: Monad](BorrowCallable):
    comptime Payload = Int
    comptime Result = Self.I.Pure[Bool]
    def invoke(self, ref value: Int) -> Self.Result:
        return pure[Self.I](value % 2 == 0)

@fieldwise_init
struct OwnedPredicate[I: Monad](BorrowCallable):
    var capture: Owned
    var calls: ArcPointer[Int]
    comptime Payload = Owned
    comptime Result = Self.I.Pure[Bool]
    def invoke(self, ref value: Owned) -> Self.Result:
        self.calls[] += 1
        return pure[Self.I](value.id == 2)

@fieldwise_init
struct Branches(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = List[Bool]
    def invoke(self, ref value: Int) -> Self.Result:
        self.calls[] += 1
        return [True, False]

@fieldwise_init
struct Borrowed[I: Monad, v: ImmOrigin, e: ImmOrigin](BorrowCallable):
    var failure: Pointer[Int, Self.e]
    comptime Payload = Pointer[Int, Self.v]
    comptime Result = Self.I.Pure[Bool]
    comptime Failure = Pointer[Int, Self.e]
    def invoke(self, ref value: Self.Payload) raises Self.Failure -> Self.Result:
        if value[] < 0:
            raise self.failure
        return pure[Self.I](True)

@fieldwise_init
struct Later(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[Bool]
    comptime Failure = Int
    def invoke(self, ref value: Int) raises Int -> Self.Result:
        self.calls[] += 1
        if value < 0:
            raise value
        return pure[Reader[Int]](value == 2)


@fieldwise_init
struct WrongPayload(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[String]
    def invoke(self, ref value: Int) -> Self.Result:
        return Optional(String(value))

@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return Optional(True)
