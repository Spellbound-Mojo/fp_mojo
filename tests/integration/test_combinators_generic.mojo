"""Generic combinator forwarding retains callback, result, origin and error types."""
from fp.algebra import ListFamily
from fp.functions import Piped, piped
from fp.iteration import Iter, MapIterator, FilterIterator, FilterNotIterator, filter_not, iterated, collect_list
from std.iter import Iterator, iter, next
from std.testing import assert_equal


def combinator_mapped[T: Movable & Deinitable, U: Movable & Deinitable, //,
                      F: def(var T) -> U](ref function: F, var source: List[T]
) -> Piped[List[U]]:
    return piped(source^).map[ListFamily](function)


def combinator_filtered[T: Movable & Deinitable, I: Iterator, //,
                        F: def(T) -> Bool](var predicate: F, var source: I
) -> Iter[FilterIterator[T, I, F]] where I.Element == T:
    return iterated(source^).filter(predicate^)



def combinator_rejected[T: Movable & Deinitable, I: Iterator, //,
                        F: def(T) -> Bool](var predicate: F, var source: I
) -> Iter[FilterNotIterator[T, I, F]] where I.Element == T:
    return iterated(source^).filter_not(predicate^)


def combinator_direct_rejected[T: Movable & Deinitable, I: Iterator, //,
                               F: def(T) -> Bool](var predicate: F, var source: I
) -> FilterNotIterator[T, I, F] where I.Element == T:
    return filter_not(source^, predicate^)


def combinator_eager_rejected[T: Movable & Deinitable, //, F: def(T) -> Bool](
    ref predicate: F, var source: List[T]
) -> Piped[List[T]]:
    return piped(source^).filter_not[ListFamily](predicate)


def combinator_eager_rejected_raised[T: Movable & Deinitable, E: Movable & Deinitable, //,
                                    F: def(T) raises E -> Bool](ref predicate: F, var source: List[T]
) raises E -> Piped[List[T]]:
    return piped(source^).filter_not[ListFamily, E=E](predicate)

def combinator_iter_mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
                          F: def(var T) -> U](var function: F, var source: I
) -> Iter[MapIterator[T, U, I, F]] where I.Element == T:
    return iterated(source^).map(function^)


def combinator_folded[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator,
                      E: AnyType, //, F: def(var A, var T) raises E -> A](
    step: F, var initial: A, var source: I
) raises E -> A where I.Element == T:
    return piped(source^).fold_left[E=E](step, initial^).get()


@fieldwise_init
struct CombinatorGenericFailure(Movable):
    var code: Int


def combinator_generic_checked(var total: Int, var value: Int) raises CombinatorGenericFailure -> Int:
    if value == 2: raise CombinatorGenericFailure(value)
    return total + value


def combinator_generic_origins(anchor: List[Int]) raises:
    var calls = 0
    def captured(var value: Int) {mut calls, anchor} -> Span[Int, origin_of(anchor)]:
        calls += value
        return Span(anchor)
    var views = combinator_mapped(captured, List[Int]([1, 2])).get()
    assert_equal(calls, 3)
    var first = views[0]
    assert_equal(first[0], 11)
    assert_equal(calls, 3)
    _ = views^
    assert_equal(first[1], 12)
    var iter_views = combinator_iter_mapped(captured, iter(range(1, 2)))
    assert_equal(next(iter_views)[0], 11)
    _ = iter_views^
    assert_equal(calls, 4)
    var threshold = 1
    def selected(value: Int) {threshold} -> Bool: return value > threshold
    assert_equal(collect_list(combinator_filtered(selected, iter(range(4)))), [2, 3])
    assert_equal(collect_list(combinator_rejected(selected, iter(range(4)))), [0, 1])
    assert_equal(collect_list(combinator_direct_rejected(selected, iter(range(4)))), [0, 1])
    assert_equal(combinator_eager_rejected(selected, List[Int]([0, 1, 2])).get(), [0, 1])
    def combinator_rejected_view(value: Span[Int, origin_of(anchor)]) {anchor} -> Bool:
        return len(value) == 0
    var retained_views: List[Span[Int, origin_of(anchor)]] = [Span(anchor)]
    var retained = combinator_eager_rejected(combinator_rejected_view, retained_views^).get()
    assert_equal(retained[0][0], 11)


def main() raises:
    combinator_generic_origins([11, 12])
    var failed = False
    try:
        _ = combinator_folded(combinator_generic_checked, 0, iter(range(5)))
    except error:
        comptime assert type_of(error) == CombinatorGenericFailure
        assert_equal(error.code, 2)
        failed = True
    assert_equal(failed, True)
    def combinator_rejection_error(value: Int) raises CombinatorGenericFailure -> Bool:
        raise CombinatorGenericFailure(value)
    failed = False
    try: _ = combinator_eager_rejected_raised(combinator_rejection_error, List[Int]([7]))
    except error:
        comptime assert type_of(error) == CombinatorGenericFailure
        failed = error.code == 7
    assert_equal(failed, True)
