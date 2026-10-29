"""Public generic clients of traversal followed by compaction or flattening."""
from fp.algebra import Traversable, FunctorFilter, Monad, Applicative, TraverseFilterContract, FlatTraverseContract
from fp.callables import UnaryContract, Unary
from fp.functions import pipeline, Pipeline

def selected[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises TraverseFilterContract[S,G,V,F].Error -> TraverseFilterContract[S,G,V,F].Out where TraverseFilterContract[S,G,V,F].InvocationCompatible:
    return pipeline[S](source^).traverse_filter[G](function^).get()

def flattened[S: Traversable & Monad, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises FlatTraverseContract[S,G,V,F].Error -> FlatTraverseContract[S,G,V,F].Out where FlatTraverseContract[S,G,V,F].InvocationCompatible:
    return pipeline[S](source^).flat_traverse[G](function^).get()

def continued[S: Traversable & Monad, G: Applicative, V: Movable & Deinitable, E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: Pipeline[S,V,E], var function: F) raises FlatTraverseContract[S,G,V,F].Error -> Pipeline[FlatTraverseContract[S,G,V,F].Family,FlatTraverseContract[S,G,V,F].Out,E] where FlatTraverseContract[S,G,V,F].InvocationCompatible:
    return source^.flat_traverse[G](function^)

@fieldwise_init
struct Select(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call(self, var value: Int) -> Self.Out:
        return Optional(Optional(value) if value % 2 == 0 else Optional[Int]())

@fieldwise_init
struct Expand(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    def call(self, var value: Int) -> Self.Out:
        return Optional(List[Int]([value,value*10]))
