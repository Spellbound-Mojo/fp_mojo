"""Named projections are reusable across free, iterator and Piped terminals."""
from fp.functions import partial, piped, pipeline, flow, as_unary
from fp.iteration import iterated, sum_by, min_by, max_by, find_map, fold_map
from fp.combinators import sum_by as combined_sum_by
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
    try: _ = fold_map[BoundedSum](project, range(1, 4))
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
    try: _ = piped(List[Int]([1, 2, 3])).fold_map[BoundedSum](project).get()
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 4)

def main() raises:
    monoid_errors()
    var project = partial(scale, 2)
    assert_equal(sum_by(project, range(4)), 12)
    assert_equal(combined_sum_by(project, range(4)), 12)
    assert_equal(iterated(range(4)).sum_by(project), 12)
    assert_equal(piped(List[Int]([1, 2, 3])).sum_by(project).get(), 12)
    assert_equal(pipeline[Int]([1, 2, 3]).sum_by(project).get(), 12)
    assert_equal(sum_by(project, range(0)), 0)
    assert_equal(min_by(project, range(4)).value(), 0)
    assert_equal(max_by(project, range(4)).value(), 3)
    assert_equal(iterated(range(4)).min_by(project).value(), 0)
    assert_equal(iterated(range(4)).max_by(project).value(), 3)
    assert_equal(piped(List[Int]([3, 1, 2])).min_by(project).get().value(), 1)
    assert_equal(piped(List[Int]([3, 1, 2])).max_by(project).get().value(), 3)
    assert_true(not min_by(project, range(0)))
    assert_true(not max_by(project, range(0)))
    var show = partial(label, String("#"))
    assert_equal(fold_map[StringMonoid](show, range(3)), "#0#1#2")
    assert_equal(iterated(range(3)).fold_map[StringMonoid](show), "#0#1#2")
    assert_equal(piped(List[Int]([0, 1, 2])).fold_map[StringMonoid](show).get(), "#0#1#2")
    assert_equal(fold_map[StringMonoid](show, range(0)), "")
    assert_equal(pipeline(range(3)).fold_map[StringMonoid](show).get(), "#0#1#2")
    assert_equal(pipeline(range(4)).min_by(project).get().value(), 0)
    assert_equal(pipeline(range(4)).max_by(project).get().value(), 3)
    var first = partial(select, 2)
    assert_equal(find_map(first, range(4)).value(), 2)
    assert_equal(iterated(range(4)).find_map(first).value(), 2)
    assert_equal(piped(List[Int]([0, 1, 2, 3])).find_map(first).get().value(), 2)
    assert_true(not find_map(first, range(0)))
    var vector = partial(lanes, Float32(2))
    assert_equal(sum_by(vector, range(4)), SIMD[DType.float32, 2](12))
    assert_equal(iterated(range(4)).sum_by(vector), SIMD[DType.float32, 2](12))
    assert_equal(piped(List[Int]([1, 2, 3])).sum_by(vector).get(), SIMD[DType.float32, 2](12))
    assert_equal(pipeline(range(4)).sum_by(vector).get(), SIMD[DType.float32, 2](12))
    var array: Array[Int, 3] = [1, 2, 3]
    assert_equal(piped(array^).sum_by(project).get(), 12)
    assert_equal(piped(Optional(3)).sum_by(project).get(), 6)
    assert_equal(piped(Optional[Int]()).sum_by(project).get(), 0)
    var queue = Deque[Int]()
    queue.append(1)
    queue.append(2)
    assert_equal(piped(queue^).sum_by(project).get(), 6)
    var linked = LinkedList[Int]()
    linked.append(1)
    linked.append(2)
    assert_equal(piped(linked^).sum_by(project).get(), 6)
    var table = Dict[String, Int]()
    table["a"] = 1
    table["b"] = 2
    assert_equal(piped(table^).sum_by(project).get(), 6)
    var chain = flow(plus_one, double)
    assert_equal(sum_by(chain, range(3)), 12)
    assert_equal(iterated(range(3)).sum_by(chain), 12)
    assert_equal(piped(List[Int]([0, 1, 2])).sum_by(chain).get(), 12)
    var native = as_unary(plus_one)
    assert_equal(sum_by(native, range(3)), 6)
    assert_equal(iterated(range(3)).sum_by(native), 6)
    assert_equal(piped(List[Int]([0, 1, 2])).sum_by(native).get(), 6)
    var failure = partial(fail, 7)
    var caught = False
    try: _ = sum_by(failure, range(1, 3))
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 8)
        caught = True
    assert_true(caught)
    caught = False
    try: _ = piped(List[Int]([1, 2])).max_by(failure).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 8)
        caught = True
    assert_true(caught)
    assert_equal(iterated(range(4)).sum_by(project^), 12)
