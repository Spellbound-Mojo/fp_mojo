# error: context that supports an error type of 'String'
from fp.algebra import Monad, OptionalFamily, ListFamily
from fp.algebra.contracts import BeforeContract
from fp.callables import ThunkContract, Thunk, OnceThunk
from fp.functions import pipeline

def kept[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> BeforeContract[I,V,F].Out where BeforeContract[I,V,F].Compatible:
    return pipeline[I](value^).before(factory^).get()

@fieldwise_init
struct Raised(Thunk):
    comptime Out = Optional[Int]
    comptime Error = Int
    def call(self) raises Int -> Self.Out: raise 721
def wrong() raises String:
    _ = kept[OptionalFamily](Optional(1), Raised())
def main() raises: wrong()
