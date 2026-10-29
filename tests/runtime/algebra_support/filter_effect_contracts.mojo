"""Generic filtering clients and an independent source with a compaction error."""
from fp.algebra import FilterEffectContract, Traversable, FunctorFilter, Applicative, ListFamily
from fp.callables import BorrowCallContract, BorrowCallable, UnaryContract
from fp.functions import pipeline, Pipeline

def filtered[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises FilterEffectContract[S,G,V,C].Error -> FilterEffectContract[S,G,V,C].Out where FilterEffectContract[S,G,V,C].InvocationCompatible:
    return pipeline[S](values^).filter_effect[G](callback^).get()

def continued[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, E: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var source: Pipeline[S,V,E], var callback: C) raises FilterEffectContract[S,G,V,C].Error -> Pipeline[FilterEffectContract[S,G,V,C].Family,FilterEffectContract[S,G,V,C].Out,E] where FilterEffectContract[S,G,V,C].InvocationCompatible:
    return source^.filter_effect[G](callback^)

@fieldwise_init
struct Even(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke(self, value: Int) -> Self.Result: return Optional(value % 2 == 0)

struct FailingCompaction(Traversable, FunctorFilter):
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapError[V,F]
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Traversed[G,V,F]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.TraverseError[G,V,F]
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapFiltered[V,F]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return ListFamily.map(function^,value^)
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.TraverseError[G,V,F] -> Self.Traversed[G,V,F]:
        return ListFamily.traverse[G](function^,value^)
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Int -> Self.MapFiltered[V,F]:
        raise 83
