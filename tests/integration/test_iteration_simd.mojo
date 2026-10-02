"""One public fold for scalar, SIMD and nonnumeric accumulators (host only)."""
from fp.iteration import fold_left
from fp.iteration import scan_left, collect_list
from std.iter import iter
from std.testing import assert_equal

# Callbacks express element operations; traversal is the same public fold.
def add_int(var acc: Int, var value: Int) -> Int:
    return acc + value

def add_text(var acc: String, var value: String) -> String:
    return acc + value

def add_vector[dtype: DType, width: Int](
    var acc: SIMD[dtype, width], var value: SIMD[dtype, width]
) -> SIMD[dtype, width]:
    return acc + value

def vectors[dtype: DType, width: Int]() raises:
    comptime V = SIMD[dtype, width]
    var first = V(0)
    var second = V(0)
    comptime for lane in range(width):
        first[lane] = Scalar[dtype](lane + 1)
        second[lane] = Scalar[dtype](10 + lane)
    var values: List[V] = [first, second]
    var result = fold_left(add_vector[dtype, width], V(0), iter(values))
    comptime assert type_of(result) == V
    comptime for lane in range(width):
        assert_equal(result[lane], Scalar[dtype](11 + 2 * lane))
    # Horizontal collapse is an explicit caller operation.
    assert_equal(result.reduce_add(), Scalar[dtype](11 * width + width * (width - 1)))
    var empty = List[V]()
    assert_equal(fold_left(add_vector[dtype, width], first, iter(empty)), first)
    var states = collect_list(scan_left(add_vector[dtype, width], V(0), iter(values)))
    assert_equal(len(states), 3)
    assert_equal(states[1], first)
    assert_equal(states[2], result)

def main() raises:
    var scalar: List[Int] = [1, 2, 3]
    assert_equal(fold_left(add_int, 0, iter(scalar)), 6)
    var text: List[String] = ["a", "b", "c"]
    assert_equal(fold_left(add_text, String("s"), iter(text)), "sabc")
    vectors[DType.int32, 2]()
    vectors[DType.int32, 4]()
    vectors[DType.float32, 4]()
    vectors[DType.float64, 8]()
