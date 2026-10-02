from fp.iteration import fold_until, reduce, EmptyReductionError
from fp.data import Break, Continue, ControlFlow
from std.iter import Iterator, StopIteration, iter
from std.testing import assert_equal, assert_true


struct Source(Iterator):
    comptime Element = Int
    var next_value: Int

    def __init__(out self):
        self.next_value = 1

    def __next__(mut self) raises StopIteration -> Int:
        # A fourth pull aborts rather than being mistaken for exhaustion.
        debug_assert[assert_mode="safe"](self.next_value <= 3, "unexpected source pull")
        var result = self.next_value
        self.next_value += 1
        return result


def step(var acc: Int, var item: Int) -> ControlFlow[String, Int]:
    if item == 3:
        return ControlFlow[String, Int](Break(String(acc + item)))
    return ControlFlow[String, Int](Continue(acc + item))


def add(var left: Int, var right: Int) -> Int:
    return left + right


def main() raises:
    var stopped = fold_until(step, 0, Source())
    assert_true(stopped.isa[Break[String]]())
    assert_equal(stopped[Break[String]].value, "6")
    var exhausted = fold_until(step, 5, iter(range(0)))
    assert_equal(exhausted[Continue[Int]].value, 5)
    assert_equal(reduce(add, iter(range(4))), 6)
    assert_equal(reduce(add, iter(range(4)), initial=10), 16)
    var caught = False
    try:
        _ = reduce(add, iter(range(0)))
    except:
        caught = True
    assert_true(caught)
