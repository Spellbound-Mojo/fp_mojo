"""Pipeline(value) selection: `pipeline` picks a family from the value's type, in concrete and generic code."""
from fp.functions import pipeline, pipeline_values
from fp.algebra import FamilyOf, ListFamily, OptionalFamily, IdentityFamily, NonEmptyListFamily, DequeFamily, LinkedListFamily
from fp.algebra.contracts import MapContract
from fp.callables import UnaryContract, as_unary
from fp.data import NonEmptyList, Result, Ok
from std.collections import Deque, LinkedList
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Point(Movable):
    var x: Int

def twice(var value: Int) -> Int: return value * 2
def positive(value: Int) -> Bool: return value > 0
def shift(var point: Point) -> Point: return Point(point.x + 1)
def size(var values: List[Int]) -> Int: return len(values)

# Generic over the carrier: no family parameter, no where clause.
def then_any[V: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var V) -> R](var value: V, function: F) -> R:
    return pipeline(value^).then(function).get()

def map_any[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var function: F) raises MapContract[FamilyOf[V], V, F].Error -> MapContract[FamilyOf[V], V, F].Out where MapContract[FamilyOf[V], V, F].Compatible:
    return pipeline(value^).map(function^).get()

def main() raises:
    # Recognized containers select their element family.
    comptime assert type_of(pipeline(List[Int]())).I == ListFamily
    comptime assert type_of(pipeline(Optional(1))).I == OptionalFamily
    comptime assert type_of(pipeline(Deque[Int]())).I == DequeFamily
    comptime assert type_of(pipeline(LinkedList[Int]())).I == LinkedListFamily
    comptime assert type_of(pipeline(NonEmptyList[Int](1))).I == NonEmptyListFamily
    assert_equal(pipeline(List[Int]([1, -2, 3])).filter(positive).map(twice).get(), List[Int]([2, 6]))
    var deque = Deque[Int]()
    deque.append(1)
    deque.append(2)
    assert_equal(pipeline(deque^).map(twice).sum().get(), 6)
    # NonEmptyList shares List's pipelines; filtering may empty it, so it continues as List.
    var mapped = pipeline(NonEmptyList[Int](1, List[Int]([2, -3]))).map(twice).get()
    assert_equal(mapped.first(), 2)
    assert_equal(len(mapped), 3)
    assert_equal(pipeline(NonEmptyList[Int](1, List[Int]([-2]))).filter(positive).get(), List[Int]([1]))
    # Anything else is one value under Identity, with no family named.
    comptime assert type_of(pipeline(3)).I == IdentityFamily
    assert_equal(pipeline(3).then(twice).map(twice).get(), 12)
    assert_equal(pipeline(Point(1)).map(shift).get().x, 2)
    var table = Dict[String, Int]()
    table["a"] = 1
    comptime assert type_of(pipeline(table.copy())).I == IdentityFamily
    assert_equal(pipeline_values(table^).sum().get(), 1)
    # Literals take their type in the bracket; explicit families still work.
    assert_equal(pipeline[List[Int]]([1, 2]).map(twice).get(), List[Int]([2, 4]))
    assert_equal(pipeline[ListFamily](List[Int]([5])).map(twice).get()[0], 10)
    assert_equal(pipeline[IdentityFamily](List[Int]([1, 2])).then(size).get(), 2)
    # Generic code.
    assert_equal(then_any(5, twice), 10)
    assert_equal(then_any(List[Int]([1, 2, 3]), size), 3)
    assert_equal(map_any(List[Int]([4]), as_unary(twice))[0], 8)
    assert_equal(map_any(Optional(4), as_unary(twice)).value(), 8)
    assert_equal(map_any(7, as_unary(twice)), 14)
