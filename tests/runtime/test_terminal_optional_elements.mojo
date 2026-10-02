"""Optional absence is an ordinary element; only source exhaustion stops a terminal."""
from fp.iteration import collect_list, find, any, all, fold_left, reduce_optional, fold_until
from fp.data import ControlFlow, Break, Continue
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct Source(Iterator):
    comptime Element = Optional[Int]
    var position: Int
    var length: Int
    var pulls: ArcPointer[Int]

    def __next__(mut self) raises StopIteration -> Self.Element:
        self.pulls[] += 1
        var position = self.position
        self.position += 1
        # Deliberately non-fused: a terminal must stop at the first exhaustion.
        if position == self.length:
            raise StopIteration()
        if position == 0:
            return None
        return Optional(position * 10)


def absent(value: Optional[Int]) -> Bool:
    return not value


def present(value: Optional[Int]) -> Bool:
    return Bool(value)


def count(var total: Int, var value: Optional[Int]) -> Int:
    return total + (100 if value else 1)


def choose_last(var first: Optional[Int], var second: Optional[Int]) -> Optional[Int]:
    return second^


def stop_at_absence(var total: Int, var value: Optional[Int]) -> ControlFlow[Optional[Int], Int]:
    if not value:
        return ControlFlow[Optional[Int], Int](Break(value^))
    return ControlFlow[Optional[Int], Int](Continue(total + value.take()))


def main() raises:
    var pulls = ArcPointer(0)
    var found = find(absent, Source(0, 2, pulls))
    assert_true(Bool(found))
    assert_false(Bool(found.value()))
    assert_equal(pulls[], 1)

    pulls[] = 0
    var values = collect_list(Source(0, 2, pulls))
    assert_equal(len(values), 2)
    assert_false(Bool(values[0]))
    assert_equal(values[1].value(), 10)
    assert_equal(pulls[], 3)

    pulls[] = 0
    assert_equal(fold_left(count, 0, Source(0, 2, pulls)), 101)
    assert_equal(pulls[], 3)

    pulls[] = 0
    var singleton = reduce_optional(choose_last, Source(0, 1, pulls))
    assert_true(Bool(singleton))
    assert_false(Bool(singleton.value()))
    assert_equal(pulls[], 2)

    pulls[] = 0
    var reduced = reduce_optional(choose_last, Source(0, 2, pulls))
    assert_equal(reduced.value().value(), 10)
    assert_equal(pulls[], 3)

    pulls[] = 0
    assert_true(any(absent, Source(0, 2, pulls)))
    assert_equal(pulls[], 1)
    pulls[] = 0
    assert_false(all(present, Source(0, 2, pulls)))
    assert_equal(pulls[], 1)

    pulls[] = 0
    var control = fold_until(stop_at_absence, 0, Source(0, 2, pulls))
    assert_true(control.isa[Break[Optional[Int]]]())
    var stopped = control^.unwrap[Break[Optional[Int]]]().into_payload()
    assert_false(Bool(stopped))
    assert_equal(pulls[], 1)
