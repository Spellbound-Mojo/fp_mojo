"""Per-call cost of `fp.match` on tiny values, against hand-written recursion.

Each sample matches the same value 100,000 times, so fixed per-call work (the
engine's stacks and memo table) dominates. Lines follow the suite's format,
`bench <name> native_ns=<median> library_ns=<median> samples=<n>`, so
`measure.py` can compare library variants.
"""
import fp
from fp.adt import Data, Cases, Node, Value
from std.time import perf_counter_ns
from std.testing import assert_equal


@fieldwise_init
struct TinyLeaf(Copyable):
    var value: Int


@fieldwise_init
struct TinyPair[R: Value](Movable):
    var left: Self.R
    var right: Self.R


struct TinyTree(Data):
    comptime Layer[R: Value] = Cases[TinyLeaf, TinyPair[R]]


comptime T = Node[TinyTree]
comptime CALLS = 100_000


def tiny_match(x: T) -> Int:
    return fp.match(x,
        lambda (l: TinyLeaf) -> Int: l.value,
        lambda (p: TinyPair[Int]) -> Int: p.left + p.right)


def tiny_native(x: T) -> Int:
    if x.isa[TinyLeaf]():
        return x[TinyLeaf].value
    ref p = x[TinyPair[T]]
    return tiny_native(p.left) + tiny_native(p.right)


@no_inline
def sample[library: Bool](x: T) -> Tuple[Int, Int]:
    var start = perf_counter_ns()
    var checksum = 0
    for _ in range(CALLS):
        comptime if library:
            checksum += tiny_match(x)
        else:
            checksum += tiny_native(x)
    return (Int(perf_counter_ns() - start), checksum)


def median(var samples: List[Int]) -> Int:
    for i in range(1, len(samples)):
        var j = i
        while j > 0 and samples[j - 1] > samples[j]:
            samples.swap_elements(j - 1, j)
            j -= 1
    return samples[len(samples) // 2]


def paired(name: String, x: T) raises:
    _ = sample[False](x)
    _ = sample[True](x)
    var native = List[Int]()
    var library = List[Int]()
    for index in range(9):
        var first: Tuple[Int, Int]
        var second: Tuple[Int, Int]
        if index % 2:
            second = sample[True](x)
            first = sample[False](x)
        else:
            first = sample[False](x)
            second = sample[True](x)
        assert_equal(first[1], second[1])
        native.append(first[0])
        library.append(second[0])
    print("bench", name, "native_ns=" + String(median(native^)), "library_ns=" + String(median(library^)), "samples=9")


def main() raises:
    paired("match_leaf_x1e5", T(TinyLeaf(3)))
    var leaf: T = TinyLeaf(1)
    paired("match_pair_x1e5", T(TinyPair(leaf, T(TinyLeaf(2)))))
    var four: T = TinyPair(T(TinyPair(leaf, leaf)), T(TinyPair(leaf, leaf)))
    paired("match_seven_x1e5", four)
