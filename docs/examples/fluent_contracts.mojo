"""Generic wrappers name the operation's output family instead of assuming one."""
from fp.algebra import Functor, Filterable, MapContract, FilterContract, ListFamily, filter
from fp.callables import UnaryContract, BorrowCallable
from fp.functions import Pipeline, pipeline, Identity


def mapped[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var values: V, var function: F) raises MapContract[I, V, F].Error -> Pipeline[MapContract[I, V, F].Family, MapContract[I, V, F].Out] where MapContract[I, V, F].Compatible:
    return pipeline[I](values^).map(function^)


def selected[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var values: V, var predicate: P) raises FilterContract[I, V, P].Error -> Pipeline[FilterContract[I, V, P].Family, FilterContract[I, V, P].Out] where FilterContract[I, V, P].Compatible and conforms_to(I.FilteredFamily, Functor):
    return Pipeline[FilterContract[I, V, P].Family, FilterContract[I, V, P].Out](filter[I](values^, predicate^))


@fieldwise_init
struct Positive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) -> Bool: return value > 0


def main() raises:
    var unchanged = mapped[ListFamily](List[Int]([1, -2, 3]), Identity[Int]()).get()
    var kept = selected[ListFamily](unchanged^, Positive()).get()
    print("kept:", kept[0], kept[1])
