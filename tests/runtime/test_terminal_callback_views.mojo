"""Named projections are reusable across free, iterator and Piped terminals."""
from fp.functions import partial, pipeline, pipeline_values, flow, as_unary
from fp.iteration import iterated, sum_by, min_by, max_by, find_map, fold_map
from fp.iteration import sum_by as combined_sum_by
from fp.algebra import StringMonoid, Monoid
from std.collections import Array, Deque, LinkedList
from std.testing import assert_equal, assert_true

def scale(factor: Int, value: Int) -> Int: return factor * value
def label(prefix: String, value: Int) -> String: return prefix + String(value)
def select(limit: Int, value: Int) -> Optional[Int]:
    if value >= limit: return Optional(value)
    return None
def lanes(factor: Float32, value: Int) -> SIMD[DType.float32, 2]:
    return SIMD[DType.float32, 2](Float32(value) * factor)
def fail(offset: Int, value: Int) raises Int -> Int: raise offset + value
def plus_one(var value: Int) -> Int: return value + 1
def double(var value: Int) -> Int: return value * 2

struct BoundedSum(Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Int -> Int:
        if right >= 4: raise right
        return left + right

def monoid_errors() raises:
    var project = partial(scale, 2)
    var caught = 0
    try: _ = fold_map[BoundedSum](range(1, 4), project)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 4)
    caught = 0
    try: _ = pipeline(range(1, 4)).fold_map[BoundedSum](project).get()
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 4)
    caught = 0
    try: _ = pipeline(List[Int]([1, 2, 3])).fold_map[BoundedSum](project).get()
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 4)

def main() raises:
    monoid_errors()
    var project = partial(scale, 2)
    assert_equal(sum_by(range(4), project), 12)
    assert_equal(combined_sum_by(range(4), project), 12)
    assert_equal(iterated(range(4)).sum_by(project), 12)
    assert_equal(pipeline(List[Int]([1, 2, 3])).sum_by(project).get(), 12)
    assert_equal(pipeline[Int]([1, 2, 3]).sum_by(project).get(), 12)
    assert_equal(sum_by(range(0), project), 0)
    assert_equal(min_by(range(4), project).value(), 0)
    assert_equal(max_by(range(4), project).value(), 3)
    assert_equal(iterated(range(4)).min_by(project).value(), 0)
    assert_equal(iterated(range(4)).max_by(project).value(), 3)
    assert_equal(pipeline(List[Int]([3, 1, 2])).min_by(project).get().value(), 1)
    assert_equal(pipeline(List[Int]([3, 1, 2])).max_by(project).get().value(), 3)
    assert_true(not min_by(range(0), project))
    assert_true(not max_by(range(0), project))
    var show = partial(label, String("#"))
    assert_equal(fold_map[StringMonoid](range(3), show), "#0#1#2")
    assert_equal(iterated(range(3)).fold_map[StringMonoid](show), "#0#1#2")
    assert_equal(pipeline(List[Int]([0, 1, 2])).fold_map[StringMonoid](show).get(), "#0#1#2")
    assert_equal(fold_map[StringMonoid](range(0), show), "")
    assert_equal(pipeline(range(3)).fold_map[StringMonoid](show).get(), "#0#1#2")
    assert_equal(pipeline(range(4)).min_by(project).get().value(), 0)
    assert_equal(pipeline(range(4)).max_by(project).get().value(), 3)
    var first = partial(select, 2)
    assert_equal(find_map(range(4), first).value(), 2)
    assert_equal(iterated(range(4)).find_map(first).value(), 2)
    assert_equal(pipeline(List[Int]([0, 1, 2, 3])).find_map(first).get().value(), 2)
    assert_true(not find_map(range(0), first))
    var vector = partial(lanes, Float32(2))
    assert_equal(sum_by(range(4), vector), SIMD[DType.float32, 2](12))
    assert_equal(iterated(range(4)).sum_by(vector), SIMD[DType.float32, 2](12))
    assert_equal(pipeline(List[Int]([1, 2, 3])).sum_by(vector).get(), SIMD[DType.float32, 2](12))
    assert_equal(pipeline(range(4)).sum_by(vector).get(), SIMD[DType.float32, 2](12))
    var array: Array[Int, 3] = [1, 2, 3]
    assert_equal(pipeline(array^).sum_by(project).get(), 12)
    assert_equal(pipeline(Optional(3)).sum_by(project).get(), 6)
    assert_equal(pipeline(Optional[Int]()).sum_by(project).get(), 0)
    var queue = Deque[Int]()
    queue.append(1)
    queue.append(2)
    assert_equal(pipeline(queue^).sum_by(project).get(), 6)
    var linked = LinkedList[Int]()
    linked.append(1)
    linked.append(2)
    assert_equal(pipeline(linked^).sum_by(project).get(), 6)
    var table = Dict[String, Int]()
    table["a"] = 1
    table["b"] = 2
    assert_equal(pipeline_values(table^).sum_by(project).get(), 6)
    var chain = flow(plus_one, double)
    assert_equal(sum_by(range(3), chain), 12)
    assert_equal(iterated(range(3)).sum_by(chain), 12)
    assert_equal(pipeline(List[Int]([0, 1, 2])).sum_by(chain).get(), 12)
    var native = as_unary(plus_one)
    assert_equal(sum_by(range(3), native), 6)
    assert_equal(iterated(range(3)).sum_by(native), 6)
    assert_equal(pipeline(List[Int]([0, 1, 2])).sum_by(native).get(), 6)
    var failure = partial(fail, 7)
    var caught = False
    try: _ = sum_by(range(1, 3), failure)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 8)
        caught = True
    assert_true(caught)
    caught = False
    try: _ = pipeline(List[Int]([1, 2])).max_by(failure).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 8)
        caught = True
    assert_true(caught)
    assert_equal(iterated(range(4)).sum_by(project^), 12)
