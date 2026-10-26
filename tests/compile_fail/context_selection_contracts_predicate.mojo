# error: invalid call to 'forward': violated constraint
from fp.algebra import Filterable, FilterContract, ListFamily, filter
from fp.callables import BorrowCallable

def forward[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var value: V, var predicate: P) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
    return filter[I](predicate^, value^)

@fieldwise_init
struct Bad(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Never
    def invoke(self, ref value: Int) -> Int: return value

def main():
    _ = forward[ListFamily](List[Int]([1]), Bad())
