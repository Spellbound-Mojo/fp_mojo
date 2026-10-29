"""Generic clients of the public borrowing traversal contract."""
from fp.algebra import TraverseTapContract, Traversable, Applicative
from fp.callables import BorrowCallContract, BorrowCallable
from fp.functions import pipeline, Pipeline


def observed[S: Traversable, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](
    var values: V, var callback: C
) raises TraverseTapContract[S,G,V,C].Error -> TraverseTapContract[S,G,V,C].Out where TraverseTapContract[S,G,V,C].InvocationCompatible:
    return pipeline[S](values^).traverse_tap[G](callback^).get()


def continued[S: Traversable, G: Applicative, V: Movable & Deinitable, E: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](
    var source: Pipeline[S,V,E], var callback: C
) raises TraverseTapContract[S,G,V,C].Error -> Pipeline[TraverseTapContract[S,G,V,C].Family,TraverseTapContract[S,G,V,C].Out,E] where TraverseTapContract[S,G,V,C].InvocationCompatible:
    return source^.traverse_tap[G](callback^)


@fieldwise_init
struct Keep[T: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.T
    comptime Result = Optional[NoneType]
    def invoke(self, value: Self.T) -> Self.Result: return Optional(NoneType())
