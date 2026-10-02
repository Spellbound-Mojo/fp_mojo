"""`fp.match` and `fp.rewrite` against hand-written native recursion on identical values.

The suite runs this program at O3 and reports each line as a diagnostic; the
timings never fail the suite. Equal checksums show both sides did the same work.
Each line is `bench <name> native_ns=<median> library_ns=<median> samples=<n>`.
"""
import fp
from fp.adt import Data, Cases, Node, Value
from std.time import perf_counter_ns
from std.testing import assert_equal


@fieldwise_init
struct BenchNum(Copyable):
    var value: Int


@fieldwise_init
struct BenchAdd[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct BenchNeg[R: Value](Movable):
    var inner: Self.R


struct BenchExpr(Data):
    comptime Layer[R: Value] = Cases[BenchNum, BenchAdd[R], BenchNeg[R]]


comptime B = Node[BenchExpr]


def library_value(x: B) -> Int:
    return fp.match(x,
        lambda (n: BenchNum) -> Int: n.value,
        lambda (a: BenchAdd[Int]) -> Int: a.left + a.right,
        lambda (n: BenchNeg[Int]) -> Int: -n.inner)


def native_value(x: B) -> Int:
    if x.isa[BenchNum]():
        return x[BenchNum].value
    if x.isa[BenchAdd[B]]():
        ref a = x[BenchAdd[B]]
        return native_value(a.left) + native_value(a.right)
    return -native_value(x[BenchNeg[B]].inner)


def library_negate(x: B) -> B:
    return fp.rewrite(x, lambda (n: BenchNum) -> B: BenchNum(-n.value))


def native_negate(x: B) -> B:
    if x.isa[BenchNum]():
        return BenchNum(-x[BenchNum].value)
    if x.isa[BenchAdd[B]]():
        ref a = x[BenchAdd[B]]
        return BenchAdd(native_negate(a.left), native_negate(a.right))
    return BenchNeg(native_negate(x[BenchNeg[B]].inner))


def balanced(depth: Int, seed: Int) -> B:
    if depth == 0:
        return BenchNum(seed % 7)
    if depth % 3 == 0:
        return BenchNeg(balanced(depth - 1, seed + 1))
    return BenchAdd(balanced(depth - 1, seed * 3 + 1), balanced(depth - 1, seed * 5 + 2))


def chain(length: Int, seed: Int) -> B:
    var x: B = BenchNum(seed)
    for i in range(length):
        x = BenchAdd(x, B(BenchNum(i % 5)))
    return x


@no_inline
def sample[kind: Int, library: Bool](x: B) -> Tuple[Int, Int]:
    var start = perf_counter_ns()
    var checksum: Int
    comptime if kind == 0:
        checksum = library_value(x) if library else native_value(x)
    else:
        var negated = library_negate(x) if library else native_negate(x)
        checksum = native_value(negated)
    return (Int(perf_counter_ns() - start), checksum)


def median(var samples: List[Int]) -> Int:
    for i in range(1, len(samples)):
        var j = i
        while j > 0 and samples[j - 1] > samples[j]:
            samples.swap_elements(j - 1, j)
            j -= 1
    return samples[len(samples) // 2]


def paired[kind: Int](name: String, x: B) raises:
    _ = sample[kind, False](x)
    _ = sample[kind, True](x)
    var native = List[Int]()
    var library = List[Int]()
    for index in range(9):
        # Alternate order; each checksum makes the measured result observable.
        var first: Tuple[Int, Int]
        var second: Tuple[Int, Int]
        if index % 2:
            second = sample[kind, True](x)
            first = sample[kind, False](x)
        else:
            first = sample[kind, False](x)
            second = sample[kind, True](x)
        assert_equal(first[1], second[1])
        native.append(first[0])
        library.append(second[0])
    print("bench", name, "native_ns=" + String(median(native^)), "library_ns=" + String(median(library^)), "samples=9")


def main() raises:
    var tree = balanced(18, 1)
    paired[0]("match_balanced", tree)
    paired[0]("match_chain", chain(10_000, 3))
    paired[1]("rewrite_balanced", tree)
