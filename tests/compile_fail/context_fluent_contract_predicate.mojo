# error: invalid call to 'selected': violated constraint
from fp.algebra import Functor, Filterable, ListFamily, filter
from fp.algebra.contracts import FilterContract
from fp.callables import BorrowCallable
from fp.functions import Pipeline

@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload = Int
    comptime Result = String
    def invoke(self, ref value: Int) -> String: return String(value)

def selected[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var value: V, var predicate: P) raises FilterContract[I,V,P].Error -> Pipeline[FilterContract[I,V,P].Family,FilterContract[I,V,P].Out] where FilterContract[I,V,P].Compatible and conforms_to(I.FilteredFamily, Functor):
    return Pipeline[FilterContract[I,V,P].Family,FilterContract[I,V,P].Out](filter[I](value^,predicate^))

def main():
    _ = selected[ListFamily](List[Int]([1]), Wrong())
