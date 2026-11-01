from fp.algebra import Monad, IdentityFamily, OptionalFamily, ListFamily, pure
from fp.algebra.contracts import AnyContract, AllContract
from fp.callables import BorrowCallable
from fp.iteration import any_effect, all_effect, iterated, Iter
from std.iter import Iterator
from fp.functions import pipeline, Pipeline
from std.testing import assert_equal
from context_find_contract_support import Even, OwnedPredicate, Branches, Borrowed, Later
from context_find_map_contract_support import Owned
from fp.algebra import ResultFamily
from fp.effects import Reader, run
from std.memory import ArcPointer
from algebra_support.box import BoxMonad

def some[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AnyContract[I, V, C].Error -> AnyContract[I, V, C].Out where AnyContract[I, V, C].Compatible:
    return any_effect[I](source^, predicate^)

def every[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AllContract[I, V, C].Error -> AllContract[I, V, C].Out where AllContract[I, V, C].Compatible:
    return all_effect[I](source^, predicate^)

def fluent[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AnyContract[I, V, C].Error -> AnyContract[I, V, C].Out where AnyContract[I, V, C].Compatible:
    return pipeline[IdentityFamily](source^).any_effect[I](predicate^).get()

def iterator_forward[I: Monad, V: Iterator, C: BorrowCallable](var predicate: C, var source: Iter[V]
) raises AllContract[I, V, C].Error -> AllContract[I, V, C].Out where AllContract[I, V, C].Compatible:
    return source^.all_effect[I](predicate^)

def selected[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AllContract[I, V, C].Error -> Pipeline[I, AllContract[I, V, C].Out] where AllContract[I, V, C].Compatible:
    return pipeline[IdentityFamily](source^).all_effect[I](predicate^)

def all_fluent[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AllContract[I, V, C].Error -> AllContract[I, V, C].Out where AllContract[I, V, C].Compatible:
    return pipeline[IdentityFamily](source^).all_effect[I](predicate^).get()

def any_iterator[I: Monad, V: Iterator, C: BorrowCallable](var predicate: C, var source: Iter[V]
) raises AnyContract[I, V, C].Error -> AnyContract[I, V, C].Out where AnyContract[I, V, C].Compatible:
    return source^.any_effect[I](predicate^)

def any_selected[I: Monad, V: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: V
) raises AnyContract[I, V, C].Error -> Pipeline[I, AnyContract[I, V, C].Out] where AnyContract[I, V, C].Compatible:
    return pipeline[IdentityFamily](source^).any_effect[I](predicate^)

@fieldwise_init
struct Absent(BorrowCallable):
    var calls: ArcPointer[Int]
    var all_values: Bool
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke(self, ref value: Int) -> Self.Result:
        self.calls[] += 1
        return Optional[Bool]() if value == 2 else Optional(self.all_values)
