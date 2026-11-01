"""Numeric effects sum in source order, with native type and target inference."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
from fp.data import Result, Ok, Err
from fp.callables import Unary
from std.collections import Array, Deque
from std.testing import assert_equal
from algebra_support.iterators import Counted
from test_combinators import CombinatorRestarting

def integer(var x: Int) -> Optional[Int]: return Optional(x)
def scalar(var x: Int) -> Result[Float64, String]: return Ok(Float64(x))
def vector(var x: Int) -> List[SIMD[DType.float32, 4]]:
    return List[SIMD[DType.float32, 4]]([SIMD[DType.float32, 4](x)])

struct LibrarySum(Unary):
    comptime Arg = Int
    comptime Out = Optional[Float32]
    def __init__(out self): pass
    def call(self, var x: Int) -> Self.Out: return Optional(Float32(x))

def main() raises:
    assert_equal(pipeline(List[Int]([1, 2, 3])).sum_by_effect(integer).get_or(0), 6)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(scalar).get_or(0), 3.0)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(vector).get()[0], SIMD[DType.float32, 4](3))
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(LibrarySum()).get_or(0), 3.0)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect[OptionalFamily](integer).get_or(0), 3)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect[OptionalFamily, type_of(integer)](integer).get_or(0), 3)
    assert_equal(pipeline(List[Int]()).sum_by_effect(integer).get_or(-1), 0)
    assert_equal(pipeline(List[Int]()).sum_by_effect(scalar).get_or(-1), 0.0)
    assert_equal(pipeline(List[Int]()).sum_by_effect(vector).get()[0], SIMD[DType.float32, 4](0))
    var array: Array[Int, 3] = [1, 2, 3]
    assert_equal(pipeline(array^).sum_by_effect(integer).get_or(0), 6)
    var deque = Deque[Int]()
    deque.append(4); deque.append(5)
    assert_equal(pipeline(deque^).sum_by_effect(integer).get_or(0), 9)
    var cursor = CombinatorRestarting(1)
    _ = cursor.__next__()
    assert_equal(pipeline(cursor^).sum_by_effect(integer).get_or(0), 5)

    def unsigned(var x: Int) -> Optional[UInt32]: return Optional(UInt32(x))
    var unsigned_total = pipeline(List[Int]([1, 2])).sum_by_effect(unsigned).get()
    comptime assert type_of(unsigned_total) == Optional[UInt32]
    assert_equal(unsigned_total.value(), UInt32(3))
    var pulls = 0
    var calls = 0
    def optional(var x: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(x) if x < 2 else Optional[Int]()
    assert_equal(pipeline(Counted(Pointer(to=pulls), 0, 5)).sum_by_effect(optional).get_or(-1), -1)
    assert_equal(pulls, 2); assert_equal(calls, 2)
    pulls = 0; calls = 0
    def result(var x: Int) {mut calls} -> Result[Int, String]:
        calls += 1
        if x == 2: return Err(String("stopped"))
        return Ok(x)
    assert_equal(pipeline(Counted(Pointer(to=pulls), 0, 5)).sum_by_effect(result).swap().get_or(""), "stopped")
    assert_equal(pulls, 2); assert_equal(calls, 2)
    def choices(var x: Int) -> List[Int]: return List[Int]([x, -x])
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(choices).get(), List[Int]([3, -1, 1, -3]))
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect[ListFamily](choices).get(), List[Int]([3, -1, 1, -3]))
    # Addition stays left-associated, including floating-point rounding.
    var floats: List[Optional[Float64]] = [Optional(Float64(1e16)), Optional(Float64(-1e16)), Optional(Float64(1))]
    assert_equal(pipeline(floats^).sum_effect().get_or(0), 1.0)
    var results = List[Result[Int, String]]()
    results.append(Ok(2)); results.append(Ok(3))
    assert_equal(pipeline(results^).sum_effect().get_or(0), 5)
    var branches: List[List[Int]] = [[1, 10], [2, 20]]
    assert_equal(pipeline(branches^).sum_effect().get(), List[Int]([3, 21, 12, 30]))
    assert_equal(pipeline(List[Optional[Float32]]()).sum_effect().get_or(-1), 0.0)
    assert_equal(pipeline(List[Result[Float64, String]]()).sum_effect().get_or(-1), 0.0)
    assert_equal(pipeline(List[List[Int]]()).sum_effect().get(), List[Int]([0]))
    assert_equal(pipeline(List[Optional[Int]]([Optional(2)])).sum_effect[OptionalFamily]().get_or(0), 2)
