"""Generic traversal forwarding preserves payload, result and raised-error origins."""
from fp.functions import piped
from fp.combinators import traverse_filter, filter_effect, flat_traverse
from fp.algebra import OptionalFamily, ListFamily, ResultFamily, Traversable, FunctorFilter
from fp.data import Result, Ok, Err
from fp.callables import Unary, BorrowCallable, UnaryContract
from std.testing import assert_equal, assert_true


def txg_flat[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //,
             F: def(var A) raises E -> Optional[List[B]]](
    ref function: F, var source: List[A]
) raises E -> Optional[List[B]]:
    return piped(source^).flat_traverse[ListFamily, OptionalFamily, E=E, X=E](function).get()


def txg_select[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //,
               F: def(var A) raises E -> Optional[Optional[B]]](
    ref function: F, var source: List[A]
) raises E -> Optional[List[B]]:
    return traverse_filter[OptionalFamily, X=E](source^, function)


def txg_filter[A: Movable & Deinitable, E: Movable & Deinitable, //,
               F: def(A) raises E -> Optional[Bool]](
    ref function: F, var source: List[A]
) raises E -> Optional[List[A]]:
    return filter_effect[OptionalFamily, X=E](source^, function)


@fieldwise_init
struct TXGFailure(Movable):
    var code: Int


def txg_groups(x: Int) raises TXGFailure -> Optional[List[Int]]:
    if x < 0: raise TXGFailure(x)
    var xs: List[Int] = [x, x * 10]
    return Optional(xs^)
def txg_present(x: Int) raises TXGFailure -> Optional[Optional[Int]]:
    if x < 0: raise TXGFailure(x)
    return Optional(Optional(x * 10))
def txg_even(x: Int) raises TXGFailure -> Optional[Bool]:
    if x < 0: raise TXGFailure(x)
    return Optional(x % 2 == 0)


@fieldwise_init
struct TXGPacket[a: ImmOrigin, b: ImmOrigin](Movable):
    var first: Span[Int, Self.a]
    var second: Span[Int, Self.b]


@fieldwise_init
struct TXGRaiseView[o: ImmOrigin](BorrowCallable):
    var failure: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Optional[Bool]
    comptime Failure = Span[Int, Self.o]
    def invoke(self, ref value: Int) raises Self.Failure capturing -> Self.Result:
        raise self.failure


def txg_origins(left: List[Int], right: List[Int]) raises:
    comptime Left = Span[Int, origin_of(left)]
    comptime Right = Span[Int, origin_of(right)]
    comptime Packet = TXGPacket[origin_of(left), origin_of(right)]
    def groups(var value: Packet) -> Optional[List[Right]]:
        var output = List[Right]()
        output.append(value.second)
        return Optional(output^)
    def present(var value: Packet) -> Optional[Optional[Right]]:
        return Optional(Optional(value.second))
    def decide(value: Left) -> Optional[Bool]: return Optional(len(value) > 0)
    var packets = List[Packet]()
    packets.append(Packet(Span(left), Span(right)))
    var flattened = flat_traverse[OptionalFamily](packets^, groups)
    assert_equal(flattened.take()[0][1], 22)
    var more = List[Packet]()
    more.append(Packet(Span(left), Span(right)))
    var selected = piped(more^).traverse_filter[OptionalFamily](present).get()
    assert_equal(selected.take()[0][1], 22)
    var views = List[Left]()
    views.append(Span(left))
    var kept = filter_effect[OptionalFamily](views^, decide)
    assert_equal(kept.take()[0][1], 12)
    var values: List[Int] = [1, 2]
    var code = 0
    try: _ = piped(values^).filter_effect[OptionalFamily](TXGRaiseView(Span(right))).get()
    except error:
        comptime assert type_of(error) == Right
        code = error[1]
    assert_equal(code, 22)
    def nested(value: Left) -> Optional[Result[Left, Right]]:
        return Optional(Result[Left, Right](Ok(value)))
    var source = Result[Left, Right](Err(Span(right)))
    var preserved = piped(source^).flat_traverse[ResultFamily[Right], OptionalFamily](nested).get()
    var stored = preserved.take()
    assert_equal(stored^._take_err()[1], 22)


def main() raises:
    var a: List[Int] = [1, 2]
    var b = a.copy()
    var c = a.copy()
    var flat: Optional[List[Int]]
    var selected: Optional[List[Int]]
    var kept: Optional[List[Int]]
    try:
        flat = txg_flat(txg_groups, a^)
        selected = txg_select(txg_present, b^)
        kept = txg_filter(txg_even, c^)
    except: raise Error("unexpected raised error")
    assert_equal(flat.take(), [1, 10, 2, 20])
    assert_equal(selected.take(), [10, 20])
    assert_equal(kept.take(), [2])
    var bad: List[Int] = [-3]
    var raised = 0
    try: _ = txg_flat(txg_groups, bad^)
    except error: raised = error.code
    assert_equal(raised, -3)
    txg_origins([11, 12], [21, 22])
    txg_custom()
    var generic_result = txg_result_library(Result[String, Int](Ok(String("payload"))))
    assert_equal(generic_result.take()._take_ok(), "payload")


struct TXGSource(Traversable, FunctorFilter):
    """An explicit source family whose compaction adds a native error."""
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapError[V, F]
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.Traversed[G, V, F]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.TraverseError[G, V, F]
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ListFamily.MapFiltered[V, F]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = TXGFailure
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        return ListFamily.map(f^, value^)
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        return ListFamily.traverse[G](f^, value^)
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises TXGFailure -> Self.MapFiltered[V, F]:
        raise TXGFailure(99)


from fp.algebra import Applicative


def txg_custom() raises:
    def present(value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value))
    var values: List[Int] = [1, 2]
    var code = 0
    try: _ = piped(values^).traverse_filter[TXGSource, OptionalFamily](present).get()
    except error:
        comptime assert type_of(error) == TXGFailure
        code = error.code
    assert_equal(code, 99)


@fieldwise_init
struct TXGResultGroup[A: Movable & Deinitable, S: Movable & Deinitable](Unary, Copyable, Defaultable):
    comptime Arg = Self.A
    comptime Out = Optional[Result[Self.A, Self.S]]
    def call(self, var value: Self.A) -> Self.Out:
        return Optional(Result[Self.A, Self.S](Ok(value^)))


def txg_result_library[A: Movable & Deinitable, S: Movable & Deinitable](
    var source: Result[A, S]
) -> Optional[Result[A, S]]:
    return piped(source^).flat_traverse[OptionalFamily](TXGResultGroup[A, S]()).get()
