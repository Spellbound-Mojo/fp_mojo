"""One allocation-free calculation shared by the host control and GPU kernel.

Inputs in [-32, 32] cover both branches, empty folds and repeated partial calls.
All owners are kernel-local; no library object is implicitly transferred.
"""
from fp.functions import flow, compose, flip, partial, as_unary
from fp.iteration import fold_left
from fp.data import Result, Ok, Err
from fp.adt import Data, Cases, Choice, Value
import fp

comptime Width = 16
comptime Output = SIMD[DType.int64, Width]
comptime Vector = SIMD[DType.int32, 4]


def twice(var x: Int) -> Int:
    return x * 2


def increment(var x: Int) -> Int:
    return x + 1


def decimal(left: Int, right: Int) -> Int:
    return 10 * left + right


def step(var total: Int, var value: Int) -> Int:
    return total * 3 + value


def success(value: Int) -> Int:
    return value + 1


def failure(value: Int) -> Int:
    return -value - 1


@fieldwise_init
struct Number(Copyable):
    var value: Int


@fieldwise_init
struct Pair(Copyable):
    var left: Int
    var right: Int


struct Shape(Data):
    comptime Layer[R: Value] = Cases[Number, Pair]


def number(n: Number) -> Int:
    return n.value + 3


def pair(p: Pair) -> Int:
    return p.left - p.right


def vector_twice(var value: Vector) -> Vector:
    return value * 2


def vector_increment(var value: Vector) -> Vector:
    return value + 1


def core(x: Int) -> Output:
    """Sixteen independently checked outputs; callback effects are all Never."""
    var result = Output(0)
    result[0] = Int64(as_unary(twice).call(x))
    var forward = flow(increment, twice)
    var backward = compose(increment, twice)
    result[1] = Int64(forward(x))
    result[2] = Int64(backward(x))
    var reversed = flip(decimal)
    result[3] = Int64(reversed(x, 3))
    var captured = x
    var bound = partial(decimal, captured)
    captured += 100
    result[4] = Int64(bound(3) + bound(4))
    var count = abs(x) % 5
    result[5] = Int64(fold_left(step, x, range(1, count + 1)))
    var value: Result[Int, Int] = Ok(x)
    if x < 0:
        value = Err(-x)
    result[6] = Int64(value.fold(success, failure))
    var subject: Choice[Shape] = Number(x)
    if x % 2 != 0:
        subject = Pair(x, 2)
    result[7] = Int64(fp.match(subject, number, pair))
    var vector = Vector(0)
    comptime for lane in range(4):
        vector[lane] = Int32(x + lane)
    var vector_flow = flow(vector_twice, vector_increment)
    var lanes = vector_flow(vector)
    comptime assert type_of(lanes) == Vector
    comptime for lane in range(4):
        result[8 + lane] = Int64(lanes[lane])
    result[12] = Int64(fold_left(step, x, range(0)))
    result[13] = Int64(flow[Int]()(x))
    result[14] = Int64(captured)
    result[15] = Int64(value.is_ok())
    return result


def expected(x: Int) -> Output:
    """Independent arithmetic oracle, used only by the host-side checks."""
    var result = Output(0)
    result[0] = Int64(2*x)
    result[1] = Int64(2*x+2)
    result[2] = Int64(2*x+1)
    result[3] = Int64(30+x)
    result[4] = Int64(20*x+7)
    var total = x
    for digit in range(1, abs(x)%5+1):
        total = 3*total+digit
    result[5] = Int64(total)
    result[6] = Int64(x+1 if x >= 0 else x-1)
    result[7] = Int64(x+3 if x%2 == 0 else x-2)
    comptime for lane in range(4):
        result[8+lane] = Int64(2*(x+lane)+1)
    result[12] = Int64(x)
    result[13] = Int64(x)
    result[14] = Int64(x+100)
    result[15] = Int64(x>=0)
    return result
