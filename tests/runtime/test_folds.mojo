from fp.iteration import fold_left, reduce_optional
from std.iter import iter, StopIteration
from std.testing import assert_equal, assert_false, assert_true


def subtract(var acc: Int, var item: Int) -> Int:
    return acc - item


@fieldwise_init
struct Accumulator(Movable):
    var text: String


def append(var acc: Accumulator, var item: Int) -> Accumulator:
    acc.text += String(item)
    return acc^


def stop(var acc: Int, var item: Int) raises StopIteration -> Int:
    raise StopIteration()


def main() raises:
    assert_equal(fold_left(subtract, 20, iter(range(1, 4))), 14)
    assert_equal(fold_left(subtract, 20, iter(range(0))), 20)
    var result = fold_left(append, Accumulator(""), iter(range(3)))
    assert_equal(result.text, "012")
    var reduced = reduce_optional(subtract, iter(range(1, 4)))
    assert_equal(reduced.value(), -4)
    assert_false(reduce_optional(subtract, iter(range(0))))
    var caught = False
    try:
        _ = fold_left(stop, 0, iter(range(3)))
    except:
        caught = True
    assert_true(caught)
    var calls = 0
    def track(var acc: Int, var item: Int) {mut calls} -> Int:
        calls += 1
        return acc + item
    assert_equal(fold_left(track, 0, iter(range(4))), 6)
    assert_equal(calls, 4)

