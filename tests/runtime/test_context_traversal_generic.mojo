"""Generic native forwarding and custom-family compaction preserve exact errors."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily, Applicative, Traversable, FunctorFilter
from fp.callables import UnaryContract
from fp.effects import Reader, run
from std.testing import assert_equal

@fieldwise_init
struct ContextTraversalCompactFailure(Movable):
    var code: Int


def forward_filter[A: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
                   F: def(A) raises E -> Optional[Bool]](
    ref[o] function: F, var source: List[A]
) raises E -> Optional[List[A]]:
    return pipeline(source^).raising[E]().filter_effect[OptionalFamily](function).get()


def forward_tap[A: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
                F: def(A) raises E -> Optional[Bool]](
    ref[o] function: F, var source: List[A]
) raises E -> Optional[List[A]]:
    return pipeline(source^).raising[E]().traverse_tap[OptionalFamily](function).get()


struct ContextTraversalSource(Traversable, FunctorFilter):
    """An explicit source family whose compaction adds a native error."""
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapError[V, F]
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Traversed[G, V, F]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.TraverseError[G, V, F]
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapFiltered[V, F]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ContextTraversalCompactFailure
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        return ListFamily.map(f^, value^)
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        return ListFamily.traverse[G](f^, value^)
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises ContextTraversalCompactFailure -> Self.MapFiltered[V, F]:
        raise ContextTraversalCompactFailure(99)


def main() raises:
    def decide(value: Int) raises ContextTraversalCompactFailure -> Optional[Bool]:
        if value < 0: raise ContextTraversalCompactFailure(value)
        return Optional(value % 2 == 0)
    var filtered: Optional[List[Int]]
    var tapped: Optional[List[Int]]
    try:
        filtered = forward_filter(decide, List[Int]([1, 2, 3]))
        tapped = forward_tap(decide, List[Int]([1, 2, 3]))
    except _: raise Error("unexpected native error")
    assert_equal(filtered.value(), List[Int]([2]))
    assert_equal(tapped.value(), List[Int]([1, 2, 3]))
    var code = 0
    try: _ = forward_filter(decide, List[Int]([-7]))
    except error: code = error.code
    assert_equal(code, -7)
    try: _ = forward_tap(decide, List[Int]([-8]))
    except error: code = error.code
    assert_equal(code, -8)

    check_origins(List[Int]([11, 12]))

    def present(value: Int) -> Optional[Bool]: return Optional(True)
    # The family adds a compaction error even though the native callback is pure.
    try: _ = pipeline[ContextTraversalSource](List[Int]([1, 2])).filter_effect[OptionalFamily](present).get()
    except error:
        comptime assert type_of(error) == ContextTraversalCompactFailure
        code = error.code
    assert_equal(code, 99)
    assert_equal(pipeline[ContextTraversalSource](List[Int]([1, 2])).traverse_tap[OptionalFamily](present).get().value(), List[Int]([1, 2]))

    comptime Deferred = Reader[Int]
    def later(value: Int) -> Deferred.Pure[Bool]: return Deferred.pure(True)
    code = 0
    # Reader postpones both callback evaluation and custom compaction.
    var pending = pipeline[ContextTraversalSource](List[Int]([1, 2])).filter_effect[Deferred](later).get()
    try: _ = run[Deferred](pending^, 0)
    except error:
        comptime assert type_of(error) == ContextTraversalCompactFailure
        code = error.code
    assert_equal(code, 99)


def check_origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    def view_present(value: View) -> Optional[Bool]: return Optional(len(value) > 0)
    var views = forward_filter(view_present, List[View]([Span(owner)]))
    assert_equal(views.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    var retained = forward_tap(view_present, List[View]([Span(owner)]))
    assert_equal(retained.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)

