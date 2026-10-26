# error: invalid call to 'tapped': lacking evidence to prove correctness
from fp.algebra import Monad, FlatTapContract, ListFamily, OptionalFamily
from fp.callables import BorrowCallContract, BorrowCallable
from fp.functions import pipeline

def tapped[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where FlatTapContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_tap(callback^).get()

@fieldwise_init
struct Borrowed[V: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.V
    comptime Result = Optional[Int]
    def invoke(self, ref value: Self.V) -> Self.Result: return Optional(1)
def reject(left: List[Int], right: List[Int]):
    comptime Right = type_of(Span(right))
    _ = tapped[OptionalFamily](Optional(Span(left)), Borrowed[Right]())
def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    reject(left, right)
