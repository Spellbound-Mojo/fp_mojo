"""Lazy selection, ordered reduction, and initial-first snapshots."""
from fp.iteration import fold_left, reduce_optional
from fp.iteration import map, filter, filter_map, flat_map, scan_left, collect_list
from fp.iteration import iterated
from fp.functions import partial, pipeline
from fp.callables import MutableUnary, MutableBinary, mut_ref
from std.testing import assert_equal

def add(var total: Int, var value: Int) -> Int:
    return total + value

def subtract(var total: Int, var value: Int) -> Int:
    return total - value

def weighted(scale: Int, total: Int, value: Int) -> Int:
    return total + scale * value

@fieldwise_init
struct Running(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var total: Int
    def call_mut(mut self, var value: Int) -> Int:
        self.total += value
        return self.total

@fieldwise_init
struct IncreasingWeight(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var weight: Int
    def call_mut(mut self, var total: Int, var value: Int) -> Int:
        total += self.weight * value
        self.weight += 1
        return total

def main() raises:
    var values: List[Int] = [-1, 1, 3]
    var tested = 0
    var mapped = 0
    var stepped = 0
    var factor = 2

    def positive(value: Int) {mut tested} -> Bool:
        tested += 1
        return value > 0

    def twice(var value: Int) {mut mapped, factor} -> Int:
        mapped += 1
        return value * factor

    def running(var total: Int, var value: Int) {mut stepped} -> Int:
        stepped += 1
        return total + value

    var selected = map(filter(values^, positive), twice)
    var scanned = scan_left(selected^, 0, running)
    assert_equal(tested, 0)
    assert_equal(mapped, 0)
    assert_equal(stepped, 0)
    var snapshots = collect_list(scanned^)
    assert_equal(tested, 3)
    assert_equal(mapped, 2)
    assert_equal(stepped, 2)
    var expected: List[Int] = [0, 2, 8]
    assert_equal(snapshots, expected)
    var checked = 0
    var expanded = 0
    var offset = 10

    def odd(var value: Int) {mut checked} -> Optional[Int]:
        checked += 1
        if value % 2: return Optional(value)
        return None

    def pair(var value: Int) {mut expanded, offset} -> List[Int]:
        expanded += 1
        return [value, value + offset]

    var pairs = flat_map(filter_map(range(1, 4), odd), pair)
    assert_equal(checked, 0)
    assert_equal(expanded, 0)
    var outputs = collect_list(pairs^)
    var expected_pairs: List[Int] = [1, 11, 3, 13]
    assert_equal(outputs, expected_pairs)
    assert_equal(checked, 3)
    assert_equal(expanded, 2)
    assert_equal(fold_left(range(1, 4), 10, subtract), 4)
    var empty = reduce_optional(range(0), add)
    assert_equal(Bool(empty), False)
    for i in range(len(snapshots)):
        print(snapshots[i])
    var step = partial(weighted, 2)
    print("weighted:", iterated(range(1, 4)).scan_left(step, 0).collect_list())
    print("again:", collect_list(scan_left(range(1, 3), 10, step)))
    print("initial:", iterated(range(0)).scan_left(step^, 5).collect_list())
    print("stateful:", iterated(range(1, 4)).map(Running(0)).collect_list())
    print("changing weights:", iterated(range(1, 4)).scan_left(IncreasingWeight(1), 0).collect_list())
    print("weighted fold:", iterated(range(1, 4)).fold_left(IncreasingWeight(1), 0))
    var step_weight = IncreasingWeight(1)
    print("pipeline fold:", pipeline[List[Int]]([1,2,3]).fold_left(mut_ref(step_weight),0).get())
    print("next weight:", step_weight.weight)
