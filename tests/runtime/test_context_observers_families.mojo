"""Generic forwarding and deferred families retain observation timing and callback borrows."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, Filterable, Functor
from fp.effects import ReaderT, run
from fp.callables import BorrowCallable
from fp.callables._predicates import _FilterPredicate
from fp.callables._transforms import _Observe
from std.testing import assert_equal
from std.memory import ArcPointer

def forward[T: Movable & Deinitable, R: Movable & Deinitable, F: def(T) -> R](ref project: F, var input: Optional[T]) -> Optional[Tuple[T, R]]:
    return pipeline(input^).pair_with(project).get()

def forward_family[I: Functor, V: Movable & Deinitable, C: BorrowCallable](var input: V, var project: C) raises I.MapError[V, _Observe[I.Element[V], C, True]] -> I.Mapped[V, _Observe[I.Element[V], C, True]] where C.Payload == I.Element[V] and I.MapCompatible[V, _Observe[I.Element[V], C, True]]:
    return pipeline[I](input^).pair_with(project^).get()

def forward_filter[I: Functor & Filterable, V: Movable & Deinitable, C: BorrowCallable](var input: V, var predicate: C) raises I.FilterError[V, _FilterPredicate[C, True]] -> I.Filtered[V, _FilterPredicate[C, True]] where C.Payload == I.Element[V] and C.Result == Bool and conforms_to(I.FilteredFamily, Functor):
    return pipeline[I](input^).filter_not(predicate^).get()

@fieldwise_init
struct ContextObserversEven(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref input: Int) capturing -> Bool: return input % 2 == 0

def main() raises:
    def length(input: String) -> Int: return input.byte_length()
    assert_equal(forward(length, Optional(String("borrowed"))).value()[1], 8)
    assert_equal(forward_family[OptionalFamily](Optional(4), ContextObserversEven()).value()[1], True)
    assert_equal(forward_filter[OptionalFamily](Optional(3), ContextObserversEven()).value(), 3)
    comptime Reader = ReaderT[OptionalFamily, Int]
    var calls = ArcPointer(List[Int]())
    def inspect(input: Int) {calls}: calls[].append(input)
    def project(input: Int) {calls} -> String:
        calls[].append(input + 10)
        return String(input)
    var pending = pipeline[Reader](Reader.pure(7)).tap_each(inspect).pair_with(project).get()
    assert_equal(len(calls[]), 0)
    var done = run[Reader](pending^, 0)
    assert_equal(done.value()[0], 7)
    assert_equal(done.value()[1], "7")
    assert_equal(calls[], List[Int]([7, 17]))
    # Discarding a deferred computation never runs its observers.
    var abandoned = pipeline[Reader](Reader.pure(9)).tap_each(inspect).pair_with(project).get()
    _ = abandoned^
    assert_equal(len(calls[]), 2)
    # Native callbacks remain usable after the deferred borrow has ended.
    inspect(11)
    assert_equal(len(calls[]), 3)

