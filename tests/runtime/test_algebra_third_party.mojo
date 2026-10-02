"""Third-party instances and computations implement the public protocols directly."""
from fp.algebra import Applicative, Monad, Traversable, Monoid, map, pure, flat_map, map2, traverse, empty, combine, ListFamily
from fp.callables import (UnaryContract, BinaryContract, ThunkContract, Binary, OnceThunk, RepeatableUnary,
                          call_once, call_repeated, as_unary)
from fp.effects import ReaderAction, StateAction, Reader, State, run
from std.builtin.rebind import rebind_var, downcast
from std.os import abort
from std.testing import assert_equal


# One exact error type or Never, as the library requires of combined callbacks.
comptime _Either[A: Movable & Deinitable, B: Movable & Deinitable]: Movable & Deinitable = B if A == Never else A


def _reraise[E: Movable & Deinitable, A: Movable & Deinitable](var error: A) raises E -> Never:
    comptime if A == Never:
        abort("cell: unreachable callback error")
    else:
        comptime assert A == E, "cell: callbacks must share one error type"
        raise rebind_var[E](error^)


trait _CellType:
    comptime Item: Movable & Deinitable


@fieldwise_init
struct Cell[T: Movable & Deinitable](Movable, _CellType):
    comptime Item = Self.T
    var value: Self.T
    def take(deinit self) -> Self.T:
        return self.value^


comptime _CellItem[V: Movable & Deinitable] = downcast[V, _CellType].Item


struct CellFamily(Monad):
    """A single-value carrier implemented as a third party would."""
    comptime Element[V: Movable & Deinitable] = _CellItem[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Cell[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Cell[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Cell[F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _Either[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        return Cell(call_once(f^, rebind_var[Cell[F.Arg]](value^).take()))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return Cell(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        comptime E = Self.CombineError[V, F, R]
        var second: F.Second
        try:
            second = rebind_var[Cell[F.Second]](call_once(right^)).take()
        except error:
            _reraise[E](error^)
        try:
            return Cell(call_once(f^, rebind_var[Cell[F.First]](left^).take(), second^))
        except error:
            _reraise[E](error^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        return call_once(f^, rebind_var[Cell[F.Arg]](value^).take())


@fieldwise_init
struct Two[T: Movable & Deinitable](Movable, _CellType):
    comptime Item = Self.T
    var first: Self.T
    var second: Self.T
    def split(deinit self, mut first: Optional[Self.T]) -> Self.T:
        first = Optional(self.first^)
        return self.second^


struct TwoFamily(Traversable):
    """A two-element source traversed in order, as a third party would."""
    comptime Element[V: Movable & Deinitable] = _CellItem[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Two[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.Combined[F.Out, _Pair[G.Element[F.Out]], _Later[F]]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _Either[
        F.Error, G.CombineError[F.Out, _Pair[G.Element[F.Out]], _Later[F]]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert RepeatableUnary[F], "two: the callback runs twice"
        var first_item = Optional[F.Arg]()
        var second_item = rebind_var[Two[F.Arg]](value^).split(first_item)
        var first = call_repeated(f, first_item.take())
        return Two(first^, call_repeated(f, second_item^))

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        comptime assert RepeatableUnary[F], "two: the callback runs twice"
        comptime E = Self.TraverseError[G, V, F]
        var first_item = Optional[F.Arg]()
        var second_item = rebind_var[Two[F.Arg]](source^).split(first_item)
        var first: F.Out
        try:
            first = call_repeated(f, first_item.take())
        except error:
            _reraise[E](error^)
        try:
            return G.map2_lazy(_Pair[G.Element[F.Out]](), first^, _Later[F](f^, second_item^))
        except error:
            _reraise[E](error^)


@fieldwise_init
struct _Pair[B: Movable & Deinitable](Binary, Defaultable):
    comptime First = Self.B
    comptime Second = Self.B
    comptime Out = Two[Self.B]
    def call(self, var first: Self.B, var second: Self.B) -> Two[Self.B]:
        return Two(first^, second^)


@fieldwise_init
struct _Later[F: UnaryContract & Movable & Deinitable](OnceThunk):
    var function: Self.F
    var item: Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return call_once(self.function^, self.item^)


struct CountMonoid(Monoid):
    """Integer addition as a third-party monoid."""
    comptime Value = Int
    @staticmethod
    def empty() -> Int:
        return 0
    @staticmethod
    def combine(var left: Int, var right: Int) -> Int:
        return left + right


@fieldwise_init
struct ReadDouble(ReaderAction):
    """A third-party Reader computation: twice the environment."""
    comptime Family = Reader[Int]
    comptime Env = Int
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Int
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) -> Int:
        return env * 2


@fieldwise_init
struct Tick(StateAction):
    """A third-party State computation: return the state, then increment it."""
    comptime Family = State[Int]
    comptime State = Int
    comptime Value = Int
    comptime Out = Tuple[Int, Int]
    def run(deinit self, var state: Int) -> Tuple[Int, Int]:
        return (state, state + 1)


def increment(var value: Int) -> Int:
    return value + 1


def next_cell(var value: Int) -> Cell[Int]:
    return Cell(value * 10)


def as_cell(var value: Int) -> Cell[Int]:
    return Cell(value + 100)


@fieldwise_init
struct Add(Binary, Copyable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int:
        return first + second


def main() raises:
    assert_equal(map[CellFamily](as_unary(increment), pure[CellFamily](1)).value, 2)
    assert_equal(flat_map[CellFamily](as_unary(next_cell), pure[CellFamily](2)).value, 20)
    assert_equal(map2[CellFamily](Add(), Cell(3), Cell(4)).value, 7)
    var mapped = map[TwoFamily](as_unary(increment), Two(1, 2))
    assert_equal(mapped.first, 2)
    assert_equal(mapped.second, 3)
    var traversed = traverse[TwoFamily, CellFamily](as_unary(as_cell), Two(1, 2))
    assert_equal(traversed.value.first, 101)
    assert_equal(traversed.value.second, 102)
    var collected = traverse[ListFamily, CellFamily](as_unary(as_cell), [1, 2, 3])
    assert_equal(collected.value, [101, 102, 103])
    assert_equal(combine[CountMonoid](empty[CountMonoid](), 5), 5)
    var environment = 21
    assert_equal(run[Reader[Int]](ReadDouble(), environment), 42)
    var state = run[State[Int]](flat_map[State[Int]](as_unary(after_tick), Tick()), 7)
    assert_equal(state[0], 8)
    assert_equal(state[1], 8)
    print("third-party instances: Monad, Traversable, Monoid, ReaderAction, StateAction")


def after_tick(var value: Int) -> type_of(pure[State[Int]](Int())):
    return pure[State[Int]](value + 1)

