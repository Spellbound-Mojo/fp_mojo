# error: invalid call to 'forward': violated constraint
from fp.algebra import Applicative, CombineContract, OptionalFamily, map2_lazy
from fp.callables import BinaryContract, ThunkContract, Binary, OnceThunk

def forward[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: V, var right: R, var function: F) raises CombineContract[I, V, F, R].Error -> CombineContract[I, V, F, R].Out where CombineContract[I, V, F, R].Compatible:
    return map2_lazy[I](function^, left^, right^)

@fieldwise_init
struct Combine(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var left: Self.First, var right: Int) -> Int: return right

@fieldwise_init
struct Right(OnceThunk):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return [7]

def main():
    _ = forward[OptionalFamily](Optional(3), Right(), Combine())
