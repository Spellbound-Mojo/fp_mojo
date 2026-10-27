# error: invalid call to 'kept': violated constraint
from fp.algebra import Monad, BeforeContract, OptionalFamily, ListFamily
from fp.callables import ThunkContract, Thunk, OnceThunk
from fp.functions import pipeline

def kept[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> BeforeContract[I,V,F].Out where BeforeContract[I,V,F].Compatible:
    return pipeline[I](value^).before(factory^).get()

@fieldwise_init
struct Once(OnceThunk):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return List[Int]([1])
def main():
    _ = kept[ListFamily](List[Int]([1,2]), Once())
