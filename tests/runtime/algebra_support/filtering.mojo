"""A deferred custom family shared by filtering runtime and ownership clients."""
from std.builtin.rebind import rebind_var
from fp.algebra import Filterable, ListFamily
from fp.callables import BorrowCallContract


@fieldwise_init
struct ContainerDeferredFilter[T: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](Movable):
    var source: List[Self.T]
    var predicate: Self.P
    def run(deinit self) raises Self.P.Failure -> List[Self.T]:
        return ListFamily.filter(self.predicate^, self.source^)

struct ContainerDeferredFamily(Filterable):
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = ContainerDeferredFilter[Self.Element[V], P]
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = Never
    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V) -> Self.Filtered[V, P]:
        comptime T = Self.Element[V]
        comptime assert V == List[T]
        return ContainerDeferredFilter[T, P](rebind_var[List[T]](value^), predicate^)
