"""Generic structural wrappers using only public contracts and operations."""
from fp.algebra import Functor
from fp.algebra.contracts import FillContract, VoidContract
from fp.callables import UnaryContract
from fp.functions import Pipeline,pipeline
def filled[I:Functor,V:Movable & Deinitable,U:Movable & Deinitable](var source:V,var replacement:U) raises FillContract[I,V,U].Error -> FillContract[I,V,U].Out where FillContract[I,V,U].InvocationCompatible:
    return pipeline[I](source^).fill(replacement^).get()

def continued[I:Functor,V:Movable & Deinitable,U:Movable & Deinitable](var source:V,var replacement:U) raises FillContract[I,V,U].Error -> Pipeline[FillContract[I,V,U].Family,FillContract[I,V,U].Out] where FillContract[I,V,U].InvocationCompatible:
    return pipeline[I](source^).fill(replacement^)

def discarded[I:Functor,V:Movable & Deinitable](var source:V) raises VoidContract[I,V].Error -> VoidContract[I,V].Out where VoidContract[I,V].InvocationCompatible:
    return pipeline[I](source^).void().get()

def refilled[I:Functor,V:Movable & Deinitable,E:Movable & Deinitable,U:Movable & Deinitable](var source:Pipeline[I,V,E],var replacement:U) raises FillContract[I,V,U].Error -> Pipeline[FillContract[I,V,U].Family,FillContract[I,V,U].Out,E] where FillContract[I,V,U].InvocationCompatible:
    return source^.fill(replacement^)

struct Failing(Functor):
    comptime Element[V:Movable & Deinitable]=V
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=F.Out
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=V
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var value:V) raises V -> F.Out:
        raise value^
