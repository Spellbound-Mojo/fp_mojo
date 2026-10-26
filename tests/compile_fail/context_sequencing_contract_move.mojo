# error: repeatable
from fp.algebra import Monad, BeforeContract, OptionalFamily, ListFamily
from fp.callables import ThunkContract, Thunk, OnceThunk
from fp.functions import pipeline

def kept[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> BeforeContract[I,V,F].Out where BeforeContract[I,V,F].Compatible:
    return pipeline[I](value^).before(factory^).get()

@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Branches(Thunk):
    comptime Out = List[Int]
    def call(self) -> Self.Out: return List[Int]([1,2])
def main():
    var source = List[Token]()
    source.append(Token(1))
    _ = kept[ListFamily](source^, Branches())
