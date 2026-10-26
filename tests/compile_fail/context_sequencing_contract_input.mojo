# error: invalid call to 'tapped': violated constraint
from fp.algebra import Monad, FlatTapContract, ListFamily, OptionalFamily
from fp.callables import BorrowCallContract, BorrowCallable
from fp.functions import pipeline

def tapped[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where FlatTapContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_tap(callback^).get()

@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload = String
    comptime Result = List[Int]
    def invoke(self, ref value: String) -> Self.Result: return List[Int]()
def main():
    _ = tapped[ListFamily](List[Int]([1]), Wrong())
