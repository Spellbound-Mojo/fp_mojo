"""Generic filter and lazy-combination wrappers retain family errors and origins."""
from fp.callables import BorrowCallContract
from fp.algebra import Filterable, Applicative, FilterContract, CombineContract, ListFamily, OptionalFamily
from fp.algebra import filter, filter_not, map2_lazy
from fp.callables import BorrowCallable, BinaryContract, ThunkContract, Binary, OnceThunk
from fp.functions import pipeline
from algebra_support.external import PublicMonad
from std.memory import ArcPointer
from std.testing import assert_equal

def selected[I: Filterable, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var value: V, var predicate: P) raises FilterContract[I, V, P].Error -> FilterContract[I, V, P].Out where FilterContract[I, V, P].Compatible:
    return filter[I](value^, predicate^)

def rejected[I: Filterable, V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var value: V, var predicate: P) raises FilterContract[I, V, P, True].Error -> FilterContract[I, V, P, True].Out where FilterContract[I, V, P, True].Compatible:
    return filter_not[I](value^, predicate^)

def combined[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: V, var right: R, var function: F) raises CombineContract[I, V, F, R].Error -> CombineContract[I, V, F, R].Out where CombineContract[I, V, F, R].Compatible:
    return map2_lazy[I](left^, right^, function^)

@fieldwise_init
struct Positive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref value: Int) -> Bool: return value > 0

@fieldwise_init
struct Plus(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var left: Int, var right: Int) -> Int: return left + right

@fieldwise_init
struct Token(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Pending(OnceThunk):
    var calls: ArcPointer[Int]
    var token: Token
    comptime Out = Optional[Int]
    def call_once(deinit self) -> Self.Out:
        self.calls[] += 1
        return Optional(7)

struct FailingFilter(Filterable):
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = Int
    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V) raises Int -> V:
        raise 733

struct PredicateFault(Filterable):
    comptime Element[V: Movable & Deinitable] = ListFamily.Element[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P
    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V) raises P -> V:
        raise predicate^

@fieldwise_init
struct NonemptyView[o: ImmOrigin](BorrowCallable):
    comptime Payload = Span[Int, Self.o]
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref value: Self.Payload) -> Bool: return len(value) > 0

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var result = selected[ListFamily](List[View]([Span(owner)]), NonemptyView[origin_of(owner)]())
    comptime assert type_of(result) == List[View]
    assert_equal(result[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)

def main() raises:
    assert_equal(selected[ListFamily](List[Int]([-1, 2, -3, 4]), Positive()), [2, 4])
    assert_equal(rejected[ListFamily](List[Int]([-1, 2, -3, 4]), Positive()), [-1, -3])
    var code = 0
    try: _ = selected[FailingFilter](List[Int]([1]), Positive())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 733)
    var saw_predicate_error = False
    try: _ = rejected[PredicateFault](List[Int]([1]), Positive())
    except error:
        comptime assert type_of(error) == FilterContract[PredicateFault, List[Int], Positive, True].Predicate
        saw_predicate_error = True
    assert_equal(saw_predicate_error, True)
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    assert_equal(combined[OptionalFamily](Optional(3), Pending(calls, Token(drops)), Plus()).value(), 10)
    assert_equal(calls[], 1)
    assert_equal(drops[], 1)
    var skipped = combined[OptionalFamily](Optional[Int](), Pending(calls, Token(drops)), Plus())
    if skipped: raise Error("empty left operand must skip combination")
    assert_equal(calls[], 1)
    assert_equal(drops[], 2)
    try: _ = combined[PublicMonad[OptionalFamily, 3]](Optional(3), Pending(calls, Token(drops)), Plus())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 704)
    assert_equal(calls[], 1)
    assert_equal(drops[], 3)
    assert_equal(pipeline[OptionalFamily](Optional(2)).map2(Optional(3), Plus()).get().value(), 5)
    origins(List[Int]([8]))
