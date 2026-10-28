"""Use the same combinators in eager pipelines and lazy iterator chains."""
from fp.functions import pipeline
from std.collections import Array
from fp.combinators import filter, filter_not, map, fold_left
from fp.iteration import iterated
from std.testing import assert_equal


def positive(value: Int) -> Bool: return value > 0
def square(value: Int) -> Int: return value * value
def add(total: Int, value: Int) -> Int: return total + value


def report(total: Int) -> String:
    return "sum of positive squares = " + String(total)


def main() raises:
    var values: List[Int] = [3, -1, 4, -1, 5]
    var direct_values = values.copy()
    var lazy_values = values.copy()
    var result = (
        pipeline(values^)
        .filter(positive)
        .sum_by(square)
        .then(report)
        .get()
    )
    var selected = filter(positive, direct_values^)
    var squared = map(square, selected^)
    var total = fold_left(add, 0, squared^)
    var lazy_total = (
        iterated(lazy_values^)
        .filter(positive)
        .sum_by(square)
    )
    assert_equal(result, "sum of positive squares = 50")
    assert_equal(total, 50)
    assert_equal(lazy_total, total)
    var fixed: Array[Int, 3] = [3, 4, 5]
    var fixed_squares = pipeline(fixed^).elements().map(square).get()
    comptime assert type_of(fixed_squares) == Array[Int, 3]
    assert_equal(fixed_squares[2], 25)
    var rejected: List[Int] = [3, -1, 4, -1, 5]
    var rejected_lazy = rejected.copy()
    assert_equal(pipeline(rejected^).filter_not(positive).map(square).get(), [1, 1])
    assert_equal(iterated(rejected_lazy^).filter_not(positive).map(square).collect_list(), [1, 1])
    assert_equal(iterated(filter_not(positive, range(-1, 2))).collect_list(), [-1, 0])
    assert_equal(iterated(range(3)).fill(7).replace(7, 9).collect_list(), [9, 9, 9])
    assert_equal(pipeline[Int]([2, 3]).pair_with(square).get(), [(2, 4), (3, 9)])
    assert_equal(pipeline[Int]([]).map(square).get(), List[Int]())
    var options: List[Optional[Int]] = [None, Optional(4), Optional(5)]
    assert_equal(pipeline(options^).compact().sum().get(), 9)
    print(result)
    var replacement: List[Int] = [7, 11]
    var filled = pipeline(Optional(1)).fill(replacement^).get()
    print("owned replacement:", filled.value())
