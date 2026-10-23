"""Direct combinator exports retain native signatures, origins and errors."""
from fp.combinators import map, filter, fold_left
from fp.functions import piped
from fp.iteration import MapIterator, FilterIterator, iterated, collect_list
from fp.iteration import map as native_map, filter as native_filter, fold_left as native_fold
from fp.callables import as_unary
from std.iter import Iterator, iter, next
from std.memory import ArcPointer
from std.testing import assert_equal
from test_combinators import (
    CombinatorItem, CombinatorFailure, CombinatorRestarting,
    CombinatorAdd, CombinatorPositive, combinator_positive, combinator_square,
    combinator_add, combinator_subtract, combinator_text, combinator_bump,
    combinator_keep, combinator_accumulate,
)


def direct_examples() raises:
    var values: List[Int] = [3, -1, 4, -1, 5]
    var direct_values = values.copy()
    var lazy_values = values.copy()
    var selected = filter(combinator_positive, direct_values^)
    var squares = map(combinator_square, selected^)
    assert_equal(fold_left(combinator_add, 0, squares^), 50)
    assert_equal(piped(collect_list(filter(combinator_positive, values^))).map(combinator_square).fold_left(combinator_add, 0).get(), 50)
    assert_equal(iterated(lazy_values^).filter(combinator_positive).map(combinator_square).fold_left(combinator_add, 0), 50)
    assert_equal(collect_list(map(combinator_text, range(3))), ["0", "1", "2"])
    assert_equal(fold_left(combinator_add, 7, range(0)), 7)
    assert_equal(fold_left(combinator_subtract, 10, range(1, 4)), 4)
    assert_equal(collect_list(map(combinator_square, range(3))), [0, 1, 4])
    assert_equal(collect_list(map(combinator_square, range(2))), [0, 1])

    # Native entry points retain their exact result types and parameter spelling.
    var direct = map[T=Int, U=Int](combinator_square, range(3))
    var legacy = native_map[T=Int, U=Int](combinator_square, range(3))
    comptime assert type_of(direct) == type_of(legacy)
    assert_equal(collect_list(direct^), [0, 1, 4])
    assert_equal(collect_list(legacy^), [0, 1, 4])
    var selected_direct = filter(combinator_positive, range(-2, 3))
    var selected_native = native_filter(combinator_positive, range(-2, 3))
    comptime assert type_of(selected_direct) == type_of(selected_native)
    assert_equal(fold_left(combinator_add, 0, selected_direct^), 3)
    assert_equal(native_fold(combinator_add, 0, selected_native^), 3)


def direct_captures() raises:
    var calls = 0
    def changing(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var mapped = map(changing, range(3))
    assert_equal(calls, 0)
    assert_equal(collect_list(mapped^), [1, 3, 5])
    assert_equal(calls, 3)
    var predicates = 0
    def every_second(value: Int) {mut predicates} -> Bool:
        predicates += 1
        return predicates % 2 == 0
    var selected = filter(every_second, range(5))
    assert_equal(predicates, 0)
    assert_equal(next(selected), 1)
    assert_equal(predicates, 2)
    _ = selected^
    assert_equal(predicates, 2)
    var bias = 1
    def shifted(var total: Int, var value: Int) {bias} -> Int:
        return total + value + bias
    assert_equal(fold_left(shifted, 0, range(3)), 6)
    var selected_library = filter(CombinatorPositive(), range(4))
    var mapped_library = map(as_unary(combinator_square), selected_library^)
    assert_equal(fold_left(CombinatorAdd(), 0, mapped_library^), 14)


def direct_moves() raises:
    var drops = ArcPointer(0)
    var values: List[CombinatorItem] = [CombinatorItem(1, drops), CombinatorItem(-1, drops), CombinatorItem(3, drops)]
    var selected = filter(combinator_keep, values^)
    var bumped = map(combinator_bump, selected^)
    var total = fold_left(combinator_accumulate, CombinatorItem(0, drops), bumped^)
    assert_equal(total.value, 6)
    assert_equal(drops[], 3)
    _ = total^
    assert_equal(drops[], 4)
    var state = CombinatorItem(10, drops)
    def owned(var value: Int) {var state^} -> Int: return value + state.value
    var captured = map(owned^, range(2))
    assert_equal(drops[], 4)
    assert_equal(collect_list(captured^), [10, 11])
    assert_equal(drops[], 5)
    var selection_state = CombinatorItem(2, drops)
    def owned_predicate(value: Int) {var selection_state^} -> Bool:
        return value >= selection_state.value
    var owned_filter = filter(owned_predicate^, range(4))
    assert_equal(next(owned_filter), 2)
    _ = owned_filter^
    assert_equal(drops[], 6)


def direct_mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
                    F: def(var T) -> U](var function: F, var source: I
) -> MapIterator[T, U, I, F] where I.Element == T:
    return map(function^, source^)


def direct_filtered[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](
    var function: F, var source: I
) -> FilterIterator[T, I, F] where I.Element == T:
    return filter(function^, source^)


def direct_folded[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator,
                    E: AnyType, //, F: def(var A, var T) raises E -> A](
    step: F, var initial: A, var source: I
) raises E -> A where I.Element == T:
    return fold_left[E=E](step, initial^, source^)


def direct_origins(anchor: List[Int]) raises:
    assert_equal(collect_list(map(combinator_square, iter(anchor))), [121, 144])
    var calls = 0
    def view(var value: Int) {mut calls, anchor} -> Span[Int, origin_of(anchor)]:
        calls += 1
        return Span(anchor)
    var mapped = direct_mapped(view, iter(range(2)))
    assert_equal(calls, 0)
    var first = next(mapped)
    assert_equal(first[0], 11)
    _ = mapped^
    assert_equal(calls, 1)
    assert_equal(first[1], 12)
    var threshold = 1
    def above(value: Int) {threshold} -> Bool: return value > threshold
    assert_equal(collect_list(direct_filtered(above, iter(range(4)))), [2, 3])
    var restarting = CombinatorRestarting(0)
    assert_equal(next(restarting), 0)
    assert_equal(collect_list(map(combinator_square, restarting^)), [1, 4, 9])


def direct_errors() raises:
    var drops = ArcPointer(0)
    var pulls = 0
    def counted(var value: CombinatorItem) {mut pulls} -> CombinatorItem:
        pulls += 1
        return value^
    def checked(var total: CombinatorItem, var value: CombinatorItem) raises CombinatorFailure -> CombinatorItem:
        if value.value == 2: raise CombinatorFailure(value.value)
        total.value += value.value
        return total^
    var values: List[CombinatorItem] = [CombinatorItem(0, drops), CombinatorItem(1, drops), CombinatorItem(2, drops), CombinatorItem(3, drops)]
    var source = map(counted, values^)
    var caught = False
    try:
        _ = direct_folded(checked, CombinatorItem(0, drops), source^)
    except error:
        comptime assert type_of(error) == CombinatorFailure
        assert_equal(error.at, 2)
        caught = True
    assert_equal(caught, True)
    assert_equal(pulls, 3)
    assert_equal(drops[], 5)
    def stop(total: Int, value: Int) raises StopIteration -> Int:
        if value == 1: raise StopIteration()
        return total + value
    caught = False
    try:
        _ = fold_left(stop, 0, range(4))
    except error:
        comptime assert type_of(error) == StopIteration
        caught = True
    assert_equal(caught, True)


def main() raises:
    direct_examples()
    direct_captures()
    direct_moves()
    direct_origins([11, 12])
    direct_errors()
    print("direct combinators: direct calls, pipelines, captures, moves, origins, exact errors")
