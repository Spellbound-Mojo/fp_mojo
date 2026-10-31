"""Use the same sequencing methods with eager and lazy values."""
from fp.functions import pipeline
from fp.callables import Thunk
from fp.iteration import iterated
from std.testing import assert_equal, assert_false


def choices(value: Int) -> List[Int]:
    if value == 2:
        return List[Int]()
    return List[Int]([value + 10, value + 20])


def next_values() -> List[Int]:
    return List[Int]([7, 8])


def unavailable() -> Optional[Int]:
    return None


@fieldwise_init
struct NextValues(Thunk):
    comptime Out = List[Int]
    var start: Int
    def call(self) -> List[Int]: return [self.start, self.start + 1]


def main() raises:
    var eager = pipeline(List[Int]([1, 2, 3])).flat_tap(choices).get()
    var lazy = iterated(range(1, 4)).flat_tap(choices).to_list()
    assert_equal(eager, [1, 1, 3, 3])
    assert_equal(lazy, eager)
    print("retained:", eager)
    var paired = pipeline(List[Int]([1, 2, 3])).flat_pair_with(choices).get()
    assert_equal(paired, [(1, 11), (1, 21), (3, 13), (3, 23)])
    assert_equal(iterated(range(1, 4)).flat_pair_with(choices).to_list(), paired)
    print("paired:", paired)

    var kept = pipeline(List[Int]([1, 2])).before(next_values).get()
    var replaced = iterated(range(2)).followed_by(next_values).to_list()
    assert_equal(kept, [1, 1, 2, 2])
    assert_equal(replaced, [7, 8, 7, 8])
    print("before:", kept)
    print("followed_by:", replaced)

    var missing = pipeline(Optional(5)).before(unavailable).get()
    assert_false(missing)
    print("optional present:", Bool(missing))
    var factory = NextValues(7)
    var first: List[Int] = [1, 2]
    print("shared before:", pipeline(first^).before(factory).get())
    var second: List[Int] = [1, 2]
    print("shared next:", pipeline(second^).followed_by(factory).get())
    assert_equal(factory.start, 7)
