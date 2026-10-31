# error: invalid call to 'kept': violated constraint
from fp.algebra import Monad, OptionalFamily, ListFamily
from fp.algebra.contracts import BeforeContract
from fp.callables import ThunkContract, Thunk, OnceThunk
from fp.functions import pipeline

def kept[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> BeforeContract[I,V,F].Out where BeforeContract[I,V,F].Compatible:
    return pipeline[I](value^).before(factory^).get()

@fieldwise_init
struct Present(Thunk):
    comptime Out = Optional[Int]
    def call(self) -> Self.Out: return Optional(1)
def main():
    _ = kept[OptionalFamily](List[Int]([1]), Present())
