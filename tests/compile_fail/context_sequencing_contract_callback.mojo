# error: does not conform to trait 'BorrowCallContract
from fp.algebra import Monad, ListFamily, OptionalFamily
from fp.algebra.contracts import FlatTapContract
from fp.callables import BorrowCallContract, BorrowCallable
from fp.functions import pipeline

def tapped[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where FlatTapContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_tap(callback^).get()

from fp.callables import Unary
@fieldwise_init
struct Wrong(Unary):
    comptime Arg = Int
    comptime Out = List[Int]
    def call(self, var value: Int) -> Self.Out: return List[Int]([value])
def main():
    _ = tapped[ListFamily](List[Int]([1]), Wrong())
