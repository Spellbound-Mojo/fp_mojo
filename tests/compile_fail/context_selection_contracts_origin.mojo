# error: invalid call to 'forward': lacking evidence to prove correctness
from fp.algebra import Filterable, ListFamily, filter
from fp.algebra.contracts import FilterContract
from fp.callables import BorrowCallable

def forward[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var value: V, var predicate: P) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
    return filter[I](value^, predicate^)

@fieldwise_init
struct Keep[P: AnyType](BorrowCallable):
    comptime Payload = Self.P
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref value: Self.P) -> Bool: return True

def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    comptime LeftView = type_of(Span(left))
    comptime RightView = type_of(Span(right))
    _ = forward[ListFamily](List[LeftView]([Span(left)]), Keep[RightView]())
